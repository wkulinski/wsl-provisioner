# Repository Guidelines

## Project Structure & Module Organization
- `site.yml` is the entry Ansible playbook; `ansible.cfg` and `inventory.ini` define local execution defaults.
- `roles/` contains the provisioning roles (`wsl_base`, `docker_engine`, `codex`, `windows_winget`), each with `tasks/main.yml` and optional templates.
- `windows/` holds Windows-side assets like `bootstrap.ps1`, `configuration.winget`, and Terminal settings.

## Build, Test, and Development Commands
- `ansible-playbook site.yml` runs the full provisioning from WSL using the default inventory.
- `DEVBOX_USER=dev ansible-playbook site.yml` sets the WSL user name created during provisioning.
- `powershell -NoProfile -ExecutionPolicy Bypass -File windows/bootstrap.ps1` runs the Windows bootstrap (Admin shell required).

## Coding Style & Naming Conventions
- Use 2-space indentation in YAML; keep Ansible tasks in `roles/<role>/tasks/main.yml`.
- Prefer `snake_case` for Ansible variables (for example, `dev_user`, `dev_home`).
- Keep role names lowercase with underscores; keep Windows scripts in `windows/`.

## Testing Guidelines
- There is no automated test suite; validate by running the playbook and checking installed tools.
- Recommended manual checks in WSL: `docker version`, `docker compose version`, `codex --version`.

## Commit & Pull Request Guidelines
- The Git history only contains an `Init` commit; no established convention yet.
- Use concise, imperative subjects (for example, "Add winget config for Terminal Preview").
- PRs should include a short summary, how to run the playbook, and any Windows-side requirements (Admin shell, reboot, or `wsl --shutdown`).

## Security & Configuration Tips
- `DEVBOX_USER` controls the created WSL user; avoid hard-coding user-specific paths.
- `ansible.cfg` disables host key checking; run only in trusted environments.
- Windows provisioning uses `winget` and modifies Terminal settings; call out changes to `windows/` assets in PRs.
