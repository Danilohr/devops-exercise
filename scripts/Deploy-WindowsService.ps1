#Requires -RunAsAdministrator
# Install HelloWorld status Windows Service (Step 4)
# Example:
#   .\Deploy-WindowsService.ps1 -ExePath "C:\Services\HelloWorld.StatusService\HelloWorld.StatusService.exe" `
#       -UserName ".\SvcUser" -Password "P@ssw0rd!"

param(
    [string]$ServiceName = "HelloWorldStatusService",
    [string]$DisplayName = "HelloWorld Status Service",
    [string]$ExePath     = "C:\Services\StatusService\StatusService.exe",
    [string]$UserName    = ".\SvcUser",
    [Parameter(Mandatory = $true)]
    [string]$Password
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ExePath)) {
    throw "Exe not found: $ExePath. Publish the status service first."
}

# Stop / remove existing service
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    if ($existing.Status -eq "Running") {
        Stop-Service -Name $ServiceName -Force
    }
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

# Create service (points to .exe, runs as specific user, auto-start)
# Note: password must be plain for sc.exe; keep it out of git (pass as param / secret)
$binPath = "`"$ExePath`""
sc.exe create $ServiceName binPath= $binPath DisplayName= $DisplayName start= auto obj= $UserName password= $Password
if ($LASTEXITCODE -ne 0) {
    throw "sc.exe create failed with exit code $LASTEXITCODE"
}

# Failure recovery: restart after 300 seconds
# reset= 86400  -> reset fail count after 1 day
# actions= restart/300000 -> restart after 300000 ms (300 seconds)
sc.exe failure $ServiceName reset= 86400 actions= restart/300000
if ($LASTEXITCODE -ne 0) {
    throw "sc.exe failure failed with exit code $LASTEXITCODE"
}

sc.exe failureflag $ServiceName 1 | Out-Null

# Start
Start-Service -Name $ServiceName

Write-Host "Done. Service '$ServiceName' installed and started."
Write-Host "Logs should appear next to the exe: $(Split-Path $ExePath -Parent)"
Get-Service -Name $ServiceName | Format-List Name, Status, StartType
