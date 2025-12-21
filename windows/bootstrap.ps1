# windows/bootstrap.ps1
# One-liner:
# powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/wkulinski/wsl-provisioner/master/windows/bootstrap.ps1 | iex"

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Log to a stable location so failures are visible after the window closes.
$LogPath = Join-Path $env:TEMP "wsl-provisioner-bootstrap.log"
$WslLogPath = Join-Path $env:TEMP "wsl-provisioner-wsl.log"
$TranscriptStarted = $false
try
{
    Start-Transcript -Path $LogPath -Append -Force | Out-Null
    $TranscriptStarted = $true
    Write-Host "Logging to: $LogPath"
    Write-Host "WSL output log (Windows): $WslLogPath"
}
catch
{
}

# PS7+: nie traktuj stderr z programów natywnych jako błędów przerywających
if ($PSVersionTable.PSVersion.Major -ge 7)
{
    $global:PSNativeCommandUseErrorActionPreference = $false
}

$SelfUrl = "https://raw.githubusercontent.com/wkulinski/wsl-provisioner/master/windows/bootstrap.ps1"
$RepoZip = "https://github.com/wkulinski/wsl-provisioner/archive/refs/heads/master.zip"
$Distro = "Ubuntu"
$RepoDir = "wsl-provisioner" # /root/code/wsl-provisioner
$TaskName = "WSLProvisioner-Continue"

function Is-Admin
{
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Elevate-Self
{
    if (Is-Admin)
    {
        return
    }
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-Command", "irm $SelfUrl | iex"
    ) | Out-Null
    exit 0
}

function Ensure-ResumeTask
{
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($null -ne $existing)
    {
        return
    }

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$env:WSL_PROVISIONER_RESUME='1'; irm $SelfUrl | iex`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
    Write-Host "Scheduled resume task '$TaskName' (will continue after reboot)."
}

function Remove-ResumeTask
{
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed resume task '$TaskName' (if it existed)."
}

function Resolve-DistroName([string]$name)
{
    try
    {
        $list = & wsl.exe -l -q 2> $null
        if ($LASTEXITCODE -ne 0)
        {
            return $null
        }
        $normalized = $list | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        if ($normalized -contains $name)
        {
            return $name
        }
        $match = $normalized | Where-Object { $_ -like "$name-*" } | Select-Object -First 1
        if ($null -ne $match -and $match -ne "")
        {
            return $match
        }
        return $null
    }
    catch
    {
        return $null
    }
}

function Has-Distro([string]$name)
{
    return [bool](Resolve-DistroName $name)
}

function Install-WSLAndDistro([string]$distroName)
{
    Write-Host "Installing WSL + $distroName using: wsl --install -d $distroName"
    try
    {
        & wsl.exe --install -d $distroName | Out-Null
    }
    catch
    {
    }

    if (-not (Has-Distro $distroName))
    {
        Write-Host "Fallback: wsl --install --web-download -d $distroName"
        & wsl.exe --install --web-download -d $distroName | Out-Null
    }
}

function Invoke-Wsl([string]$command, [string]$context)
{
    Write-Host "WSL: $context"
    $prevErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try
    {
        $command | & wsl.exe -d $Distro -u root -- bash -s 2>&1 | Tee-Object -FilePath $WslLogPath -Append
    }
    finally
    {
        $ErrorActionPreference = $prevErrorAction
    }
    if ($LASTEXITCODE -ne 0)
    {
        throw "WSL step failed ($context) with exit code $LASTEXITCODE. See $WslLogPath."
    }
}

Elevate-Self

# Phase 0: WSL + Ubuntu install (simple), with fallback --web-download
$Stage = "init"
$ExitCode = 0
try
{
    Write-Host "Starting WSL provisioner bootstrap."
    Write-Host "Target distro: $Distro"
    $ResolvedDistro = Resolve-DistroName $Distro
    if (-not $ResolvedDistro)
    {
        $Stage = "install-wsl"
        Write-Host "WSL distro '$Distro' not found. Installing..."
        Ensure-ResumeTask
        Install-WSLAndDistro -distroName $Distro
        Write-Host "Rebooting after WSL install..."
        Restart-Computer -Force
        exit 0
    }

    $Distro = $ResolvedDistro
    Write-Host "Detected WSL distro: $Distro"
    Remove-ResumeTask

    # Phase 1: run Ansible in WSL as root (Ansible will create/configure dev user)
    $Stage = "detect-user"
    Write-Host "Detecting default WSL user..."
    $DetectedUser = & wsl.exe -d $Distro -u root -- bash -lc @'
set -euo pipefail
user=""
if [ -f /etc/wsl.conf ]; then
  user=$(awk -F= '
    /^\s*\[user\]\s*$/ { in_user=1; next }
    /^\s*\[/ { in_user=0 }
    in_user && $1 ~ /^\s*default\s*$/ {
      gsub(/[[:space:]]/, "", $2); print $2; exit
    }' /etc/wsl.conf)
fi
if [ -n "$user" ]; then
  echo "$user"
  exit 0
fi
awk -F: '$3>=1000 && $1!="nobody" {print $1; exit}' /etc/passwd
'@
    if ($LASTEXITCODE -ne 0)
    {
        $DetectedUser = ""
    }
    else
    {
        $DetectedUser = ($DetectedUser | Out-String).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($DetectedUser))
    {
        $DetectedUser = ($env:USERNAME -replace '[^a-zA-Z0-9_-]', '_').ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($DetectedUser))
        {
            $DetectedUser = "dev"
        }
    }

    $DevUser = $DetectedUser
    Write-Host "Using WSL dev user: $DevUser"

    $Stage = "install-ansible"
    Write-Host "Installing Ansible prerequisites in WSL..."
    $installPrereqs = @'
set -euo pipefail
set -x
echo "[bootstrap] Installing Ansible prerequisites..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ansible curl unzip
'@
    Invoke-Wsl -command $installPrereqs -context "install-ansible"

    $Stage = "run-playbook"
    Write-Host "Running Ansible playbook (site.yml)..."
    $downloadRepo = @'
set -euo pipefail
set -x
echo "[bootstrap] Downloading repository ZIP..."
mkdir -p /root/code
tmpzip=/tmp/wsl-provisioner.zip
tmpdir=/tmp/wsl-provisioner-unzip
rm -f "$tmpzip"
rm -rf "$tmpdir"
curl -fsSL -L "__REPOZIP__" -o "$tmpzip"
mkdir -p "$tmpdir"
echo "[bootstrap] Unpacking repository..."
unzip -q "$tmpzip" -d "$tmpdir"
rm -rf /root/code/__REPODIR__
mv "$tmpdir"/wsl-provisioner-master /root/code/__REPODIR__
'@
    $downloadRepo = $downloadRepo.Replace("__REPOZIP__", $RepoZip).Replace("__REPODIR__", $RepoDir)
    Invoke-Wsl -command $downloadRepo -context "download-repo"

    $runPlaybook = @'
set -euo pipefail
set -x
echo "[bootstrap] Running ansible-playbook..."
cd /root/code/__REPODIR__
export DEVBOX_USER="__DEVUSER__"
ansible-playbook -i inventory.ini site.yml
'@
    $runPlaybook = $runPlaybook.Replace("__REPODIR__", $RepoDir).Replace("__DEVUSER__", $DevUser)
    Invoke-Wsl -command $runPlaybook -context "ansible-playbook"

    # If Ansible enabled systemd but it isn't active yet, shutdown WSL and run playbook again
    $Stage = "post-systemd"
    Write-Host "Checking if systemd activation requires WSL shutdown..."
    & wsl.exe -d $Distro -u root -- bash -lc "test -f /var/lib/devbox/requires_wsl_shutdown" 1> $null 2> $null
    if ($LASTEXITCODE -eq 0)
    {
        Write-Host "systemd enabled but not active yet -> running: wsl --shutdown, then playbook again"
        & wsl.exe --shutdown
        $postShutdown = @'
set -euo pipefail
set -x
cd /root/code/__REPODIR__
export DEVBOX_USER="__DEVUSER__"
ansible-playbook -i inventory.ini site.yml
'@
        $postShutdown = $postShutdown.Replace("__REPODIR__", $RepoDir).Replace("__DEVUSER__", $DevUser)
        Invoke-Wsl -command $postShutdown -context "ansible-playbook-after-shutdown"
    }

    Write-Host "✅ Done. WSL provisioning finished. Dev user: $DevUser"
}
catch
{
    $ExitCode = 1
    Remove-ResumeTask
    Write-Host "❌ Bootstrap failed (stage: $Stage)."
    Write-Host "Error: $($_.Exception.Message)"
    if ($_.InvocationInfo)
    {
        Write-Host $_.InvocationInfo.PositionMessage
    }
    switch ($Stage)
    {
        "install-wsl" {
            Write-Host "Check WSL installation and rerun:"
            Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -Command `"irm $SelfUrl | iex`""
        }
        "install-ansible" {
            Write-Host "Retry prerequisites in WSL, then rerun the script or playbook:"
            Write-Host "wsl -d $Distro -u root -- bash -lc 'apt-get update -y && apt-get install -y ansible curl unzip'"
        }
        "run-playbook" {
            Write-Host "Retry the playbook:"
            Write-Host "wsl -d $Distro -u root -- bash -lc 'cd /root/code/$RepoDir && ansible-playbook -i inventory.ini site.yml'"
        }
        "post-systemd" {
            Write-Host "If systemd isn't active yet, run on Windows: wsl --shutdown"
            Write-Host "Then rerun the playbook:"
            Write-Host "wsl -d $Distro -u root -- bash -lc 'cd /root/code/$RepoDir && ansible-playbook -i inventory.ini site.yml'"
        }
        Default {
            Write-Host "Rerun the bootstrap script:"
            Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -Command `"irm $SelfUrl | iex`""
        }
    }
}
finally
{
    if ($TranscriptStarted)
    {
        try
        {
            Stop-Transcript | Out-Null
        }
        catch
        {
        }
    }

    $isInteractive = [Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost"
    if ($ExitCode -ne 0 -and $isInteractive -and -not $env:WSL_PROVISIONER_RESUME)
    {
        Write-Host "Press Enter to close..."
        [void](Read-Host)
    }
}

exit $ExitCode
