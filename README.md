# wsl-provisioner

Automatyczny provisioning środowiska developerskiego: **Windows + WSL (Ubuntu) + Docker (w WSL) + Codex + PhpStorm + Windows Terminal (Preview, Quake mode)**.

Repo zawiera:
- `windows/bootstrap.ps1`: bootstrap na Windows (Admin) → instaluje WSL + Ubuntu (z fallback `--web-download`), pobiera ZIP repo, odpala Ansible w WSL.
- `site.yml` + role Ansible: właściwa konfiguracja WSL i Windows (przez `winget.exe` uruchamiany z WSL).

## Co to instaluje i konfiguruje

### Windows
- Windows Terminal **Preview**
- PhpStorm
- Podkłada `settings.json` dla Terminal Preview:
  - `compatibility.allowHeadless = true`
  - `windowingBehavior = useExisting`
  - skrót `Ctrl+\`` → Quake toggle
  - `startOnUserLogin = false` (żeby nie dublować autostartu)
- Dodaje skrót do Autostartu użytkownika uruchamiający **Quake mode** przy logowaniu:
  - `wt.exe -w _quake`

> Uwaga: jeśli masz zainstalowany też “stable” Terminal, `wt.exe` może wskazywać na stable lub preview
> (ustawienia „App execution aliases” w Windows decydują).

### WSL (Ubuntu)
- Tworzy użytkownika dev (z ENV `DEVBOX_USER`, domyślnie `dev`) + `sudo` bez hasła
- Bazowe narzędzia CLI: `git`, `openssh-client`, `curl`, `unzip`, `jq`, `ripgrep`
- Włącza `systemd=true` w `/etc/wsl.conf`
- Docker Engine + docker compose plugin (w WSL)
- nvm + Node.js 22 (default)
- Codex CLI: `npm i -g @openai/codex@latest`
- Dodaje użytkownika dev do grupy `docker`

## Użycie (najprościej)

1) Otwórz **Windows Terminal / PowerShell jako Administrator**
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

## Gdzie ląduje repo w WSL?
Skrypt bootstrap pobiera ZIP repo do: `/root/code/wsl-provisioner` i stamtąd odpala playbook.
Dalej Twoje projekty trzymaj w `/home/<dev_user>/code/...` (np. `~/code`).

## Wskazówki
- Jeśli terminal nie startuje jako Quake przy logowaniu: sprawdź czy skrót w Autostarcie istnieje
  oraz czy `wt.exe` jest włączony w „App execution aliases”.
