param(
  [switch]$EnableMirroredNetworking
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) {
  Write-Host ("[INFO] " + $msg)
}

function Ensure-Dir($path) {
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Force -Path $path | Out-Null
  }
}

# --- CONFIG (łatwe do automatyzacji / zmiany) ---
$Port = "64342"
$UserProfile = $env:USERPROFILE
$CmdPath = Join-Path $UserProfile "bin\phpstorm-mcp.cmd"

# Ścieżka do JBR (Java) z PhpStorm (jak w "Copy Stdio Config" - może być bez .exe)
$JavaPath = "C:\Users\wojci\AppData\Local\Programs\PhpStorm\jbr\bin\java"
if (-not ($JavaPath.ToLower().EndsWith(".exe"))) {
  $JavaPathExe = $JavaPath + ".exe"
} else {
  $JavaPathExe = $JavaPath
}

# Pełny classpath dokładnie jak w JSON z "Copy Stdio Config"
$Classpath = "C:\Users\wojci\AppData\Local\Programs\PhpStorm\plugins\mcpserver\lib\mcpserver-frontend.jar;C:\Users\wojci\AppData\Local\Programs\PhpStorm\lib\util-8.jar;C:\Users\wojci\AppData\Local\Programs\PhpStorm\lib\module-intellij.libraries.ktor.client.cio.jar;C:\Users\wojci\AppData\Local\Programs\PhpStorm\lib\module-intellij.libraries.ktor.client.jar;C:\Users\wojci\AppData\Local\Programs\PhpStorm\lib\module-intellij.libraries.ktor.network.tls.jar;C:\Users\wojci\AppData\Local\Programs\PhpStorm\lib\module-intellij.libraries.ktor.io.jar;C:\Users\wojci\AppData\Local\Programs\PhpStorm\lib\module-intellij.libraries.ktor.utils.jar;C:\Users\wojci\AppData\Local\Programs\PhpStorm\lib\module-intellij.libraries.kotlinx.io.jar;C:\Users\wojci\AppData\Local\Programs\PhpStorm\lib\module-intellij.libraries.kotlinx.serialization.core.jar;C:\Users\wojci\AppData\Local\Programs\PhpStorm\lib\module-intellij.libraries.kotlinx.serialization.json.jar"

$MainClass = "com.intellij.mcpserver.stdio.McpStdioRunnerKt"

# --- 1) Optional: enable WSL mirrored networking ---
if ($EnableMirroredNetworking) {
  $WslConfigPath = Join-Path $UserProfile ".wslconfig"
  $WslConfigContent = @"
[wsl2]
networkingMode=mirrored
"@

  Write-Info "Enabling WSL mirrored networking in $WslConfigPath"
  Set-Content -Path $WslConfigPath -Value $WslConfigContent -Encoding ASCII

  Write-Info "Applied .wslconfig. Run (PowerShell): wsl --shutdown"
  Write-Info "Then re-open WSL."
}

# --- 2) Create the MCP runner CMD ---
Ensure-Dir (Join-Path $UserProfile "bin")

$cmd = @"
@echo off
set IJ_MCP_SERVER_PORT=$Port

"$JavaPathExe" ^
  -classpath "$Classpath" ^
  $MainClass
"@

Write-Info "Writing $CmdPath"
Set-Content -Path $CmdPath -Value $cmd -Encoding ASCII

Write-Info "Done."
Write-Info "Manual PhpStorm step: Settings -> Tools -> MCP Server -> Enable MCP Server."
Write-Info "When PhpStorm is running, it should listen on 127.0.0.1:$Port."
Write-Info "PowerShell test: Get-NetTCPConnection -State Listen -LocalPort $Port"
