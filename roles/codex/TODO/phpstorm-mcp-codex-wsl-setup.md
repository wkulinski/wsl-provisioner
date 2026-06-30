# PhpStorm MCP (Windows) + Codex CLI (WSL) — kompletna procedura + skrypty

Ta instrukcja konfiguruje **JetBrains/PhpStorm MCP Server** tak, aby **Codex CLI uruchamiany w WSL** mógł korzystać z narzędzi IDE (nawigacja po indeksach, inspekcje, refaktoryzacje itp.) przez **MCP transport `stdio`**.

Docelowy układ:
- **IDE (PhpStorm) działa na Windows**
- **kod + codex działają w WSL**
- Codex startuje **Windowsowy proces** (Java z PhpStorm) przez `cmd.exe`, a komunikacja z Codexem idzie po **STDIO**

> Dlaczego `stdio` a nie SSE?
> Codex CLI oficjalnie wspiera `stdio` i `Streamable HTTP`, a konfiguracja JetBrains “Copy Stdio Config” jest 1:1 kompatybilna z `command/args/env` w `.codex/config.toml`.  
> Dokumentacja Codex MCP: https://developers.openai.com/codex/mcp/  
> Dokumentacja JetBrains MCP Server: https://www.jetbrains.com/help/phpstorm/mcp-server.html

---

## Co dostajesz w paczce

- `setup-phpstorm-mcp-windows.ps1`  
  Tworzy:
  - `%UserProfile%\.wslconfig` (opcjonalnie, mirrored networking)
  - `%UserProfile%\bin\phpstorm-mcp.cmd` (wrapper uruchamiający MCP STDIO runner JetBrains)

- `setup-phpstorm-mcp-wsl.sh`  
  Tworzy/aktualizuje:
  - `~/.codex/config.toml` (dodaje serwer MCP `phpstorm`)

---

## Wymagania

### Windows
- PhpStorm z wbudowanym MCP Server (w UI jest: *Settings → Tools → MCP Server*).

### WSL
- Codex CLI z działającą konfiguracją.

---

## Krok 0 — manualnie w PhpStorm (tylko informacyjnie)

1. Otwórz PhpStorm
2. Wejdź w: **Settings → Tools → MCP Server**
3. Zaznacz: **Enable MCP Server**
4. Kliknij: **Copy Stdio Config**
5. Skopiowany JSON zawiera m.in.:
   - `IJ_MCP_SERVER_PORT` (u Ciebie: `64342`)
   - `command` (java z PhpStorm)
   - `args` (classpath + main class)

Ta instrukcja i skrypty zakładają dokładnie ten port i classpath (poniżej w kodzie).

---

## Krok 1 — Windows: uruchom skrypt PowerShell

> Skrypt jest idempotentny: możesz go odpalać wielokrotnie.

### 1.1 Uruchom

PowerShell (Windows), w katalogu gdzie masz `setup-phpstorm-mcp-windows.ps1`:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\setup-phpstorm-mcp-windows.ps1 -EnableMirroredNetworking
```

Parametr:
- `-EnableMirroredNetworking` — tworzy/aktualizuje `%UserProfile%\.wslconfig` z `networkingMode=mirrored` i sugeruje `wsl --shutdown`.
  Mirrored mode: https://learn.microsoft.com/en-us/windows/wsl/networking

### 1.2 Co skrypt tworzy

- `%UserProfile%\bin\phpstorm-mcp.cmd` (pełny classpath jak w Twoim JSON; nic nie jest „ucięte”)
- (opcjonalnie) `%UserProfile%\.wslconfig`

---

## Krok 2 — WSL: uruchom skrypt bash

WSL (Linux), w katalogu gdzie masz `setup-phpstorm-mcp-wsl.sh`:

```bash
chmod +x ./setup-phpstorm-mcp-wsl.sh
./setup-phpstorm-mcp-wsl.sh
```

Skrypt dopisze (lub zaktualizuje) wpis w `~/.codex/config.toml`:

- MCP server name: `phpstorm`
- command: `/mnt/c/Windows/System32/cmd.exe`
- args: `["/c", "C:\\Users\\wojci\\bin\\phpstorm-mcp.cmd"]`

---

## Krok 3 — testy (twarde i szybkie)

### 3.1 Windows: czy PhpStorm nasłuchuje na porcie MCP

> PhpStorm musi być uruchomiony, MCP Server włączony.

PowerShell (Windows):

```powershell
Get-NetTCPConnection -State Listen -LocalPort 64342
```

Oczekujesz `LocalAddress = 127.0.0.1` i `State = Listen`.

### 3.2 WSL: czy widzisz Windows localhost (tylko jeśli włączyłeś mirrored)

```bash
sudo apt-get update && sudo apt-get install -y netcat-openbsd
nc -vz 127.0.0.1 64342
```

### 3.3 Codex: czy MCP działa

W Codex TUI wpisz:
- `/mcp`

Powinieneś zobaczyć serwer `phpstorm` jako aktywny i listę narzędzi.

---

## Najczęstsze problemy

### A) „handshaking … initialize response”
- zwykle: quoting/classpath/uruchomienie złym procesem
- dlatego używamy wrappera `.cmd` na Windows + `cmd.exe` jako `command` w Codex

### B) port nie nasłuchuje w Windows
- sprawdź czy w PhpStorm włączony MCP Server
- upewnij się, że port jest zgodny z “Copy Stdio Config”

---

## Parametry do zmiany w przyszłości (gdy zmienisz użytkownika/instalację)
W skryptach są jawne wartości (łatwe do “obszycia”):
- port: `64342`
- ścieżka do java: `C:\Users\wojci\AppData\Local\Programs\PhpStorm\jbr\bin\java`
- classpath: pełny, zgodny z JSON
- ścieżka do `.cmd`: `%UserProfile%\bin\phpstorm-mcp.cmd`

Jeśli PhpStorm się zaktualizuje i “Copy Stdio Config” zmieni classpath, podmień go w skrypcie Windows i uruchom ponownie.

---

# Skrypty

Poniżej są w osobnych plikach:
- `setup-phpstorm-mcp-windows.ps1`
- `setup-phpstorm-mcp-wsl.sh`
