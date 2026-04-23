#!/bin/bash

# setup-raspberry.sh - Automatyczna konfiguracja Raspberry Pi dla MelexTourAudio
# Bazuje na instrukcji instructions.md

set -e  # Zatrzymaj skrypt przy pierwszym błędzie

echo "🥧 Automatyczna konfiguracja Raspberry Pi dla MelexTourAudio"
echo "============================================================="

# Funkcja do wyświetlania kroków
log_step() {
    echo ""
    echo "🔧 $1"
    echo "----------------------------------------"
}

# Funkcja sprawdzająca czy komenda się powiodła
check_command() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ $1 - BŁĄD!"
        exit 1
    fi
}

log_step "KROK 1: Instalacja Nginx"
# Aktualizujemy listę pakietów i instalujemy Nginx
sudo apt update
check_command "Aktualizacja listy pakietów"

sudo apt install -y nginx
check_command "Instalacja Nginx"

log_step "KROK 2: Konfiguracja Nginx jako reverse proxy"

sudo systemctl restart nginx 
# Tworzymy plik konfiguracyjny dla aplikacji
sudo tee /etc/nginx/sites-available/melex > /dev/null << 'EOF'
server {
    listen 80 default_server;
    server_name rp.local;  # zamień na IP lub domenę Twojego Raspberry Pi

    location / {
        proxy_pass         http://127.0.0.1:5115;  # port, na którym działa Twoja aplikacja
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        
        # SignalR specific settings
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Upgrade $http_upgrade;
        proxy_read_timeout 86400;
    }
}
EOF
check_command "Utworzenie pliku konfiguracyjnego Nginx"

log_step "KROK 3: Aktywacja konfiguracji i restart Nginx"
# Włączamy konfigurację, testujemy ją i przeładowujemy Nginx
sudo ln -s /etc/nginx/sites-available/melex /etc/nginx/sites-enabled/
check_command "Włączenie konfiguracji melex"

sudo nginx -t
check_command "Test konfiguracji Nginx"

sudo systemctl reload nginx
check_command "Przeładowanie Nginx"

log_step "PRZYGOTOWANIE: Utworzenie katalogu aplikacji"
# Tworzymy katalog dla aplikacji (potrzebny dla usługi systemowej)
sudo mkdir -p /var/www/melex
sudo chown mk:mk /var/www/melex
check_command "Utworzenie katalogu /var/www/melex"

log_step "KROK 4: Utworzenie usługi systemowej systemd"
# Tworzymy plik usługi systemowej dla aplikacji .NET
sudo tee /etc/systemd/system/melex.service > /dev/null << 'EOF'
[Unit]
Description=Melex .NET Application
After=network.target

[Service]
WorkingDirectory=/var/www/melex
ExecStart=/var/www/melex/MelexTourAudio
Restart=always
RestartSec=5
User=mk
Environment=DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
Environment=ASPNETCORE_URLS=http://0.0.0.0:5115

[Install]
WantedBy=multi-user.target
EOF
check_command "Utworzenie usługi systemowej melex.service"

log_step "KROK 5: Aktywacja usługi"
# Przeładowujemy konfigurację systemd i włączamy usługę
sudo systemctl daemon-reload
check_command "Przeładowanie konfiguracji systemd"

sudo systemctl enable melex.service
check_command "Włączenie automatycznego uruchamiania usługi"

# Uwaga: Nie uruchamiamy usługi teraz, bo aplikacja jeszcze nie jest wdrożona
echo "⚠️  Usługa zostanie uruchomiona automatycznie po wdrożeniu aplikacji"

log_step "KROK 6: Sprawdzenie konfiguracji"
# Sprawdzamy czy Nginx działa poprawnie
sudo systemctl status nginx --no-pager
check_command "Sprawdzenie statusu Nginx"

# Sprawdzamy czy usługa melex jest poprawnie skonfigurowana
sudo systemctl is-enabled melex.service >/dev/null 2>&1
check_command "Sprawdzenie konfiguracji usługi melex"

echo ""
echo "🎉 KONFIGURACJA ZAKOŃCZONA POMYŚLNIE!"
echo "====================================="
echo ""
echo "📋 Co zostało skonfigurowane:"
echo "   ✅ Nginx zainstalowany i skonfigurowany jako reverse proxy"
echo "   ✅ Konfiguracja Nginx dla aplikacji (port 80 → 5115)"
echo "   ✅ Katalog aplikacji /var/www/melex utworzony"
echo "   ✅ Usługa systemowa melex.service skonfigurowana"
echo "   ✅ Automatyczne uruchamianie usługi przy starcie systemu"
echo ""
echo "🚀 NASTĘPNY KROK:"
echo "   Wróć do swojego komputera Mac i uruchom:"
echo "   ./deploy.sh"
echo ""
echo "🌐 Po wdrożeniu aplikacja będzie dostępna pod adresem:"
echo "   http://$(hostname -I | awk '{print $1}')"
echo "   http://rp.local"
echo ""
echo "💡 SPRAWDZENIE PO WDROŻENIU:"
echo "   sudo systemctl status melex.service"
echo "   curl http://localhost"
echo ""
