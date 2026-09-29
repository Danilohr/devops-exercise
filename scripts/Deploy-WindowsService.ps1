#Requires -RunAsAdministrator
# Install HelloWorld status Windows Service (Step 4)
# Example:
#   .\Deploy-WindowsService.ps1 -ExePath "C:\Services\StatusService\StatusService.exe" `
#       -UserName ".\SvcUser" -Password "P@ssw0rd!"
#
# Requires: Carbon.Security (grants "Log on as a service" to the service account)

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

# Carbon.Security - used for Grant-CPrivilege (SeServiceLogonRight)
if (-not (Get-Module -ListAvailable -Name Carbon.Security)) {
    Install-Module Carbon.Security -Scope CurrentUser -Force
}
Import-Module Carbon.Security

$localUser = $UserName.TrimStart('.\')
$svcUser   = ".\$localUser"
$secure    = ConvertTo-SecureString $Password -AsPlainText -Force

# Create local user if missing
if (-not (Get-LocalUser -Name $localUser -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $localUser -Password $secure -PasswordNeverExpires -UserMayNotChangePassword | Out-Null
}

# Allow the service account to read/run the app and write logs
$exeDir = Split-Path $ExePath -Parent
icacls $exeDir /grant "${localUser}:(OI)(CI)M" /T | Out-Null

# Stop / remove existing service
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    if ($existing.Status -eq "Running") {
        Stop-Service -Name $ServiceName -Force
    }
    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

# Create service: specific user, auto-start
$binPath = "`"$ExePath`""
sc.exe create $ServiceName binPath= $binPath DisplayName= "$DisplayName" start= auto obj= $svcUser password= $Password
if ($LASTEXITCODE -ne 0) { throw "sc.exe create failed: $LASTEXITCODE" }

# Grant "Log on as a service"
Grant-CPrivilege -Identity $svcUser -Privilege 'SeServiceLogonRight'

# Failure recovery: restart up to 3 times, 300 seconds between each
# reset= 86400 - fail count resets after 1 day
sc.exe failure $ServiceName reset= 86400 actions= restart/300000/restart/300000/restart/300000
if ($LASTEXITCODE -ne 0) { throw "sc.exe failure failed: $LASTEXITCODE" }
sc.exe failureflag $ServiceName 1 | Out-Null

Start-Service -Name $ServiceName

Write-Host "Done. Service '$ServiceName' running as $svcUser"
Write-Host "Logs: $exeDir"
Get-Service -Name $ServiceName | Format-List Name, Status, StartType
