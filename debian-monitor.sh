#!/bin/bash

# Ścieżka do plików dziennika
log_file="/home/ubuntu/log/debianstat.log"
error_log="/home/ubuntu/log/debianmirror-error.log"
info_log="/home/ubuntu/log/debianmirror.log"

# Ścieżka do skryptu pobierającego mirror
mirror_script="/home/ubuntu/packages/debian-ftp.sh"

# Ścieżka lustra
mirror_path="/srv/ftp/debianmirror"

# Adres URL paczki
PACKAGE_URL="http://ftp.cz.debian.org/debian/"

# Flaga kontrolna dla trybu testowego
TEST_MODE=false
#TEST_MODE=true
# Funkcje logowania
log_message() {
    # Logowanie wiadomości do pliku dziennika
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M") - $message" >> "$log_file"
}

log_info() {
    # Logowanie informacji do pliku dziennika
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M") [INFO] - $message" >> "$info_log"
}

log_warning() {
    # Logowanie ostrzeżeń do pliku dziennika
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M") [OSTRZEŻENIE] - $message" >> "$error_log"
}

log_error() {
    # Logowanie błędów do pliku dziennika
    local message="$1"
    echo "$(date +"%Y-%m-%d %H:%M") [BŁĄD] - $message" >> "$error_log"
}

# Funkcja logująca wykonywane operacje
log_operations() {
    if [ -n "$BASH_COMMAND" ]; then
        log_info "Wykonywana operacja: $BASH_COMMAND"
        
        # Dodajemy zapisywanie operacji otwierania plików
        if [[ $BASH_COMMAND =~ ^[[:space:]]*(cat|echo|touch|mv|cp|rm|mkdir) ]]; then
            for word in $BASH_COMMAND; do
                if [ -f "$word" ]; then
                    log_info "Otwierany plik: $word"
                fi
            done
        fi
        
        # Dodajemy zapisywanie operacji dostępu do zasobów wewnątrz serwera
        if [[ $BASH_COMMAND =~ ^[[:space:]]*try_access_inside_server ]]; then
            resource=$(echo "$BASH_COMMAND" | awk '{print $2}')
            log_info "Próba dostępu do zasobu wewnątrz serwera: $resource"
        fi
    fi
}


# Funkcja sprawdzająca, czy istnieje połączenie z internetem
check_internet_connection() {
    ping -c 1 google.com > /dev/null 2>&1 || {
        log_error "Błąd: Brak połączenia z internetem. Sprawdź swoje połączenie."
        exit 1
    }
}

# Funkcja sprawdzająca uprawnienia dostępu do katalogu lustra
check_mirror_permissions() {
    if [ ! -d "$mirror_path" ]; then
        log_error "Błąd: Katalog $mirror_path nie istnieje lub brak do niego odpowiednich uprawnień."
        exit 1
    fi
}

# Funkcja sprawdzająca zawartość lustra
check_mirror_content() {
    log_info "Sprawdzanie zawartości katalogu lokalnego..."
    if [ ! -d "$mirror_path" ]; then
        log_error "Błąd: Katalog $mirror_path nie istnieje."
        exit 1
    fi

    if [ -z "$(ls -A "$mirror_path")" ]; then
        log_warning "Zawartość lokalna: mirror_path jest pusty."
    else
        log_info "Zawartość lokalna: mirror_path zawiera dane."
    fi
}

# Funkcja próbująca uzyskać dostęp do zasobów
try_access() {
    local message="$1"
    log_warning "Próba uzyskania dostępu: $message"
    sleep 5s
}

# Funkcja próbująca wskrzesić działanie
revive_action() {
    local action="$1"
    local attempt=1
    while true; do
        log_warning "Próba wskrzeszenia działania ($attempt): $action"
        sleep 5s
        "$action" && break
        ((attempt++))
    done
}

# Funkcja próbująca uzyskać dostęp do zasobów wewnątrz serwera
try_access_inside_server() {
    local resource="$1"
    if [ ! -e "$resource" ]; then
        log_warning "Zasób $resource nie istnieje."
        # Tutaj można dodać kod próbujący utworzyć zasób lub podejmujący inne działania w celu jego odtworzenia
    fi
}

# Funkcja zbierająca metadane o plikach z URL
collect_URL_metadata() {
    log_info "Pobieranie metadanych plików z adresu URL..."
    wget -q -O /tmp/debian_index.html "$PACKAGE_URL" > /dev/null 2>&1 || {
        log_error "Błąd podczas pobierania strony."
        exit 1
    }

    # Analiza zawartości strony i wyodrębnienie nazw katalogów oraz dat modyfikacji (zmodyfikuj jeśli tabela po zmianie domeny pobierania się rozjeżdza ) 
    sed -n '/<table>/,/<\/table>/p' /tmp/debian_index.html | grep -oP '(?<=<a href=")[^"]+' | sed 's#\.\./##' | sed '/^$/d' | sed '/\.\.\//d' | sed 's/\/$//' | grep -vE '\?|^/$'|sed '/^$/d' > /tmp/debian_names.txt

    sed -n '/<table>/,/<\/table>/p' /tmp/debian_index.html | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' > /tmp/debian_dates.txt

    # Połączenie nazw katalogów i plików z datami do jednego pliku
    paste -d '\t' /tmp/debian_names.txt /tmp/debian_dates.txt > /tmp/debian_directories_with_dates.txt
   
    # Usunięcie tymczasowych plików
   # rm -f /tmp/debian_index.html /tmp/debian_names.txt /tmp/debian_dates.txt
}

collect_local_metadata() {
    local mirror_path="$1"
    
    # Sprawdzenie, czy katalog istnieje
    if [ ! -d "$mirror_path" ]; then
        log_error "Błąd: Katalog $mirror_path nie istnieje."
        return 1
    fi

    # Pobranie metadanych
    cd "$mirror_path" || {
        log_error "Błąd: Brak dostępu do katalogu $mirror_path."
        return 1
    }

    # Sortowanie danych lokalnych według nazw plików
    find . -maxdepth 1 ! -name '.*' -printf "%f\t%TY-%Tm-%Td %TH:%TM\n" | sort -k1 > /tmp/debian_local_directories_with_dates.txt || {
        log_error "Błąd: Nie udało się pobrać metadanych z lokalnego lustra."
        return 1
    }

    log_info "Plik z metadanymi został utworzony: /tmp/debian_local_directories_with_dates.txt"
}


# Funkcja porównująca metadane
compare_metadata() {
    ignore_threshold=180 # Próg ignorowania różnic czasu (w minutach)
    
    # Ustawienie nagłówków
    printf "%-25s | %-20s | %-20s | %-11s\n" "Nazwa pliku" "Data (URL)" "Data (lokalnie)" "Aktualność"
    # Ustawienie linii podziału
    printf "%s\n" "--------------------------------------------------------------------------------------"
    
    paste -d '\t' /tmp/debian_directories_with_dates.txt /tmp/debian_local_directories_with_dates.txt | awk -v ignore_threshold="$ignore_threshold" 'BEGIN { FS="\t" } {
        split($2, url_date_parts, /[-: ]/)
        split($4, local_date_parts, /[-: ]/)
        url_year = url_date_parts[1]; url_month = url_date_parts[2]; url_day = url_date_parts[3]; url_hour = url_date_parts[4]; url_minute = url_date_parts[5]
        local_year = local_date_parts[1]; local_month = local_date_parts[2]; local_day = local_date_parts[3]; local_hour = local_date_parts[4]; local_minute = local_date_parts[5]
        url_timestamp = mktime(url_year " " url_month " " url_day " " url_hour " " url_minute " 0")
        local_timestamp = mktime(local_year " " local_month " " local_day " " local_hour " " local_minute " 0")
        time_difference = url_timestamp - local_timestamp
        if (time_difference <= ignore_threshold * 60) {
            up_to_date = "Aktualne"
        } else {
            if (url_year > local_year) {
                up_to_date = "Nieaktualne"
            } else if (url_year < local_year) {
                up_to_date = "Aktualne"
            } else if (url_month > local_month) {
                up_to_date = "Nieaktualne"
            } else if (url_month < local_month) {
                up_to_date = "Aktualne"
            } else if (url_day > local_day) {
                up_to_date = "Nieaktualne"
            } else if (url_day < local_day) {
                up_to_date = "Aktualne"
            } else if (url_hour > local_hour) {
                up_to_date = "Nieaktualne"
            } else if (url_hour < local_hour) {
                up_to_date = "Aktualne"
            } else if (url_minute > local_minute) {
                up_to_date = "Nieaktualne"
            } else {
                up_to_date = "Aktualne"
            }
        }
        printf "%-25s | %-20s | %-20s | %-11s\n", $1, $2, $4, up_to_date
    }'
    
    printf "%s\n" "--------------------------------------------------------------------------------------"
}

# Funkcja sprawdzająca aktualizacje i informująca o potrzebie aktualizacji
check_for_updates() {
    log_info "Sprawdzanie aktualizacji..."
    local need_update=false
    while read -r line; do
        if [[ "$line" == *Nieaktualne* ]]; then
            need_update=true
            break
        fi
    done < <(compare_metadata)

    if [ "$need_update" = true ]; then
        log_warning "Dane są nieaktualne. Proszę przeprowadzić aktualizację."
        if [ "$TEST_MODE" = true ]; then
            log_info "Tryb testowy: Aktualizacja pominięta."
        else
            if [ -x "$mirror_script" ]; then
                log_info "Uruchamianie skryptu aktualizującego lustra..."
                log_message "Rozpoczęcie aktualizacji lustra."
                "$mirror_script" || {
                    log_error "Błąd podczas uruchamiania skryptu aktualizującego lustra."
                    log_message "Błąd podczas aktualizacji lustra."
                    exit 1
                }
                log_info "Aktualizacja lustra zakończona sukcesem."
                log_message "Aktualizacja lustra zakończona sukcesem."
            else
                log_error "Błąd: Skrypt aktualizacji lustra nie jest dostępny lub nie ma uprawnień do wykonania."
                exit 1
            fi
        fi
    else
        log_info "Dane są aktualne. Koniec sesji monitorowania."
        log_message "Dane są aktualne. Koniec sesji monitorowania."
    fi
}

# Obsługa błędów
trap 'log_error "Wystąpił nieoczekiwany błąd w linii $LINENO."; exit 1;' ERR


# 1. Sprawdzenie połączenia z internetem
log_info "1. Sprawdzanie połączenia z internetem..."
if check_internet_connection; then
    log_info "Połączenie z internetem działa poprawnie."
else
    log_error "Błąd podczas sprawdzania połączenia z internetem."
    exit 1
fi

# 2. Sprawdzenie uprawnień dostępu do katalogu  mirrora
log_info "2. Sprawdzanie uprawnień dostępu do katalogu mirrora..."
if check_mirror_permissions; then
    log_info "Uprawnienia dostępu do katalogu mirrora zostały pomyślnie sprawdzone."
else
    log_error "Błąd podczas sprawdzania uprawnień dostępu do katalogu mirrora."
    exit 1
fi

# 3. Sprawdzenie zawartości mirroru
log_info "3. Sprawdzanie zawartości mirrora..."
if check_mirror_content; then
    log_info "Zawartość mirrora  została pomyślnie sprawdzona."
else
    log_error "Błąd podczas sprawdzania zawartości mirrora."
    exit 1
fi

# 4. Wywołanie funkcji zbierającej metadane URL
log_info "4. Pobieranie metadanych plików z adresu URL..."
if collect_URL_metadata; then
    log_info "Metadane plików z adresu URL zostały pomyślnie pobrane."
else
    log_error "Błąd podczas pobierania metadanych plików z adresu URL."
    exit 1
fi

# 5. Wywołanie funkcji zbierającej metadane lokalne
log_info "5. Pobieranie metadanych lokalnych..."
if collect_local_metadata "$mirror_path" ; then
    log_info "Metadane lokalne zostały pomyślnie pobrane."
else
    log_error "Błąd podczas pobierania metadanych lokalnych."
    exit 1
fi

# 6. Wywołanie funkcji porównującej metadane
log_info "6. Porównywanie metadanych..."
log_info "Różnica czasu może wynikać z innych stref czasowych jendkaże monitoring wykryje do 3h różnic czasowych"
compare_metadata >> "$info_log"

# 7. Sprawdzenie aktualizacji
log_info "7. Sprawdzanie aktualizacji..."
check_for_updates >> "$info_log"

# 8. Oddzielenie sesji w dzienniku logów
log_info "Sesja monitorowania zakończona."
echo "------------------------------------------------------------------" >> "$info_log"
