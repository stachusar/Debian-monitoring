# Opis Skryptu Mirror Update

## Spis Treści
[Opis](#opis)  
[Wymagania](#wymagania)  
[Struktura Skryptu](#struktura-skryptu)  
[Instrukcja Użytkowania](#instrukcja-użytkowania)  
[Działanie Skryptu](#działanie-skryptu)  
[Dostosowanie Skryptu](#dostosowanie-skryptu)    
[Legenda Pojęć](#legenda-pojęć)  

## Opis

Skrypt służy do monitorowania i aktualizacji lokalnego mirroru repozytorium Debian. Automatyzuje proces sprawdzania aktualności plików względem zdalnego serwera, pobiera metadane i, w przypadku wykrycia nieaktualnych plików, inicjuje aktualizację.

## Wymagania
* System operacyjny: Linux
* Zainstalowane narzędzia: `bash`, `wget`, `sed`, `awk`, `ping`, `find`
* Dostęp do internetu
* Dostępne uprawnienia do zarządzania plikami i katalogami w określonych lokalizacjach

## Struktura Skryptu
1. __Ścieżki do plików dziennika__: ścieżki do logów informacyjnych, ostrzeżeń oraz błędów.
2. __Ścieżka do skryptu mirror__: lokalizacja skryptu odpowiedzialnego za aktualizację mirrora.
3. __Ścieżka do mirrora__: lokalizacja katalogu z lokalnym mirrorem repozytorium.
4. __Funkcje logowania__: funkcje do zapisu różnych typów komunikatów w odpowiednich logach.
5. __Funkcje pomocnicze__: zbiór funkcji realizujących kluczowe operacje, takie jak sprawdzanie połączenia internetowego, uprawnień do katalogów, pobieranie metadanych, porównywanie metadanych, a także zarządzanie błędami i wyjątkami.

## Działanie Skryptu
Skrypt wykonuje serię zdefiniowanych kroków:

1. Sprawdza połączenie z internetem.
2. Sprawdza uprawnienia dostępu do katalogu mirrora.
3. Sprawdza zawartość lokalnego mirrora.
4. Pobiera metadane z adresu URL.
5. Pobiera metadane lokalne.
6. Porównuje metadane zdalne i lokalne.
7. Na podstawie porównania, decyduje o potrzebie aktualizacji.
8. Rejestruje wszystkie działania i wyniki w plikach logów.

## Instrukcja Użytkowania
1. __Ustawienie Skryptu__: Upewnij się, że wszystkie ścieżki w skrypcie są poprawnie ustawione zgodnie z Twoją konfiguracją systemu.
2. __Uruchomienie Skryptu__: Skrypt uruchamia się poleceniem `./nazwa_skryptu.sh` z uprawnieniami umożliwiającymi zapis do lokalizacji mirrora i plików log.
3. __Monitoring__: Skrypt loguje wszystkie operacje do odpowiednich plików dziennika, więc monitorowanie postępu jest możliwe przez sprawdzenie tych plików.
4. __Aktualizacje__: W przypadku wykrycia nieaktualnych plików, skrypt automatycznie uruchomi procedurę aktualizacji (o ile nie jest włączony tryb testowy).

### Administrator
* Upewnij się, że masz odpowiednie uprawnienia do wykonania skryptu.
* Regularnie sprawdzaj logi, aby monitorować stan i ewentualne błędy.
* Konfiguruj i aktualizuj ścieżki w skrypcie zgodnie z potrzebami systemu.

### Użytkownik
* Skrypt jest przeznaczony głównie dla administratorów lub zaawansowanych użytkowników z odpowiednią wiedzą techniczną.
* Jeśli masz dostęp do uruchomienia skryptu, upewnij się, że rozumiesz jego funkcje i wpływ na system.



## Dostosowanie Skryptu

### 1. __Ścieżki i Ustawienia__:
* `log_file`, `error_log`, `info_log`: Ścieżki do plików dziennika można zmieniać w zależności od struktury katalogów systemu.
*  `mirror_script`, `mirror_path`, `PACKAGE_URL`: Te zmienne należy dostosować do lokalizacji skryptu aktualizacyjnego, ścieżki mirrora i adresu URL repozytorium.
#### Przykładowe dostosowanie ścieżek:
```bash
# Ścieżka do plików dziennika
log_file="/var/log/debianstat.log"
error_log="/var/log/debianmirror-error.log"
info_log="/var/log/debianmirror.log"
```
### 2. __Funkcje Logowania__:
Możesz dostosować formatowanie i zawartość komunikatów logowania w funkcjach `log_message`, `log_info`, `log_error` itp.


### Legenda Pojęć
__Mirror repozytorium__: Lokalna kopia danych z repozytorium zdalnego, służąca do szybszego dostępu i redukcji obciążenia sieci.
__Metadane__: Informacje opisujące dane, takie jak ich rozmiar, data modyfikacji, lokalizacja itp.
__Aktualizacja mirroru__: Proces synchronizacji lokalnego mirrora z repozytorium zdalnym w celu zapewnienia jego aktualności.
