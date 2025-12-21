# wsl-provisioner

Automatyczny provisioning środowiska developerskiego: **Windows + WSL (Ubuntu) + Docker (w WSL) + Codex + JetBrains Toolbox + Docker Desktop + Warp**.

Repo zawiera:
- `windows/bootstrap.ps1`: bootstrap na Windows (Admin) → instaluje WSL + Ubuntu (z fallback `--web-download`), pobiera archiwum repo, odpala Ansible w WSL.
- `site.yml` + role Ansible: właściwa konfiguracja WSL i Windows (przez `winget.exe` uruchamiany z WSL).

## Co to instaluje i konfiguruje

### Windows
- JetBrains Toolbox
- Docker Desktop
- Warp (terminal)

### WSL (Ubuntu)
- Tworzy użytkownika dev (z ENV `DEVBOX_USER`, domyślnie `dev`) + `sudo` bez hasła
- Bazowe narzędzia CLI: `git`, `openssh-client`, `curl`
- Włącza `systemd=true` w `/etc/wsl.conf`
- Docker Engine + docker compose plugin (w WSL)
- nvm + Node.js 22 (default)
- Codex CLI: `npm i -g @openai/codex@latest`
- Dodaje użytkownika dev do grupy `docker`

## Użycie (najprościej)

1) Otwórz **PowerShell jako Administrator**
2) Wklej one-liner:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/wkulinski/wsl-provisioner/master/windows/bootstrap.ps1 | iex"
```

Skrypt:
- zainstaluje WSL/Ubuntu jeśli trzeba (i zrestartuje Windows, jeśli wymagane),
- po restarcie sam dokończy (Scheduled Task),
- odpali provisioning Ansible w WSL,
- jeśli Ansible włączy `systemd=true`, zrobi `wsl --shutdown` i odpali playbook drugi raz (żeby systemd/Docker wstały poprawnie).

## Sprawdzenie po instalacji

W WSL:

```bash
docker version
docker compose version
codex --version
```

## Logi i diagnoza

W Windows (PowerShell) log WSL:

```powershell
Get-Content -Path $env:TEMP\wsl-provisioner-wsl.log -Tail 200
```

## Uruchamianie polecen z Windows do WSL

Przyklad uruchomienia komendy jako root w Ubuntu:

```powershell
wsl -d Ubuntu -u root -- bash -lc "apt-get install -y XXX"
```

## Gdzie ląduje repo w WSL?
Skrypt bootstrap pobiera archiwum repo do: `/root/code/wsl-provisioner` i stamtąd odpala playbook.
Dalej Twoje projekty trzymaj w `/home/<dev_user>/code/...` (np. `~/code`).
