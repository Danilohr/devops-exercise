# Deploy HelloWorld Docker image (Step 6)
# Uses your Docker Hub image, or docker.io/library/hello-world as fallback.
# Example:
#   .\Deploy-Docker.ps1 -Image "youruser/helloworld:latest"
#   .\Deploy-Docker.ps1 -Image "hello-world"   # official fallback

param(
    [string]$Image         = "hello-world",
    [string]$ContainerName = "helloworld",
    [int]$HostPort         = 8080,
    [int]$ContainerPort    = 8080
)

$ErrorActionPreference = "Stop"

# Remove existing container with the same name
$existing = docker ps -a --filter "name=^/${ContainerName}$" --format "{{.ID}}"
if ($existing) {
    Write-Host "Removing existing container: $ContainerName"
    docker rm -f $ContainerName | Out-Null
}

Write-Host "Pulling $Image ..."
docker pull $Image
if ($LASTEXITCODE -ne 0) {
    throw "docker pull failed for $Image"
}

# Official hello-world exits immediately; app image stays up and maps a port
if ($Image -eq "hello-world" -or $Image -like "*/hello-world*") {
    docker run --name $ContainerName $Image
}
else {
    docker run -d --name $ContainerName -p "${HostPort}:${ContainerPort}" $Image
    if ($LASTEXITCODE -ne 0) {
        throw "docker run failed"
    }
    Write-Host "Running: http://localhost:${HostPort}/health"
    docker ps --filter "name=^/${ContainerName}$"
}

Write-Host "Done."
