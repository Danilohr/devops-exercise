#Requires -RunAsAdministrator
# Deploy HelloWorld to IIS (Step 2)
# Example:
#  .\Deploy-IIS.ps1 -SourcePath "C:\publish\HelloWorld" -UserName ".\IisAppUser" -Password "P@ssw0rd!"

param(
    [string]$SiteName       = "HelloWorldSite",
    [string]$AppName        = "HelloWorld",
    [string]$AppPoolName    = "HelloWorldAppPool",
    [string]$SitePath       = "C:\inetpub\HelloWorldSite",
    [string]$AppPath        = "C:\inetpub\HelloWorldSite\HelloWorld",
    [string]$LogPath        = "C:\inetpub\logs\HelloWorldSite",
    [string]$SourcePath     = "C:\publish\HelloWorld",
    [string]$GroupName      = "HelloWorldIIS",
    [string]$UserName       = ".\IisAppUser",
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [int]$HttpPort          = 8080,
    [int]$HttpsPort         = 8443
)

Import-Module WebAdministration

$ErrorActionPreference = "Stop"

# 1. Local group + user 
if (-not (Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue)) {
    New-LocalGroup -Name $GroupName -Description "HelloWorld IIS app pool group"
}

$localUser = $UserName.TrimStart('.\')
if (-not (Get-LocalUser -Name $localUser -ErrorAction SilentlyContinue)) {
    $secure = ConvertTo-SecureString $Password -AsPlainText -Force
    New-LocalUser -Name $localUser -Password $secure -PasswordNeverExpires -UserMayNotChangePassword
}

Add-LocalGroupMember -Group $GroupName -Member $localUser -ErrorAction SilentlyContinue

# 2. Folders 
foreach ($p in @($SitePath, $AppPath, $LogPath)) {
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

# Copy published app into the application folder
if (-not (Test-Path $SourcePath)) {
    throw "SourcePath not found: $SourcePath. Publish the app first."
}
Copy-Item -Path (Join-Path $SourcePath "*") -Destination $AppPath -Recurse -Force

# Give the app-pool user read/execute on the app folder
icacls $AppPath /grant "${localUser}:(OI)(CI)RX" /T

# 3. App pool (runs as the specified user) 
if (Test-Path "IIS:\AppPools\$AppPoolName") {
    Remove-WebAppPool -Name $AppPoolName
}
New-WebAppPool -Name $AppPoolName
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name managedRuntimeVersion -Value ""
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name processModel.identityType -Value SpecificUser
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name processModel.userName -Value $UserName
Set-ItemProperty "IIS:\AppPools\$AppPoolName" -Name processModel.password -Value $Password

# 4. Website + HTTPS binding 
if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
    Remove-Website -Name $SiteName
}

# Self-signed cert for HTTPS (local demo)
$cert = Get-ChildItem Cert:\LocalMachine\My |
    Where-Object { $_.Subject -eq "CN=localhost-helloworld" } |
    Select-Object -First 1
if (-not $cert) {
    $cert = New-SelfSignedCertificate -DnsName "localhost" -FriendlyName "HelloWorld IIS" `
        -CertStoreLocation "Cert:\LocalMachine\My" -Subject "CN=localhost-helloworld"
}

New-Website -Name $SiteName -PhysicalPath $SitePath -Port $HttpPort -HostHeader "localhost" -ApplicationPool $AppPoolName | Out-Null
New-WebBinding -Name $SiteName -Protocol https -Port $HttpsPort -IPAddress "*"
$binding = Get-WebBinding -Name $SiteName -Protocol https
$binding.AddSslCertificate($cert.Thumbprint, "My")

# 5. Custom log path 
Set-ItemProperty "IIS:\Sites\$SiteName" -Name logFile.directory -Value $LogPath

# 6. Application under the site 
if (Get-WebApplication -Site $SiteName -Name $AppName -ErrorAction SilentlyContinue) {
    Remove-WebApplication -Site $SiteName -Name $AppName
}
New-WebApplication -Site $SiteName -Name $AppName -PhysicalPath $AppPath -ApplicationPool $AppPoolName | Out-Null

Write-Host "Done."
Write-Host "HTTP:  http://localhost:${HttpPort}/${AppName}/health"
Write-Host "HTTPS: https://localhost:${HttpsPort}/${AppName}/health"
