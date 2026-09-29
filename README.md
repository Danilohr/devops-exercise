# DevOps Hello World

Demonstration of a small IIS + CI/CD pipeline: a .NET HelloWorld API, a Windows Service that logs its HTTP status, PowerShell deploy scripts, and an optional Docker image.

## Projects

| Project | Role |
|---------|------|
| `src/HelloWorld` | ASP.NET Core API - `GET /health` returns `Hello World!` |
| `src/StatusService` | Windows Service - checks the IIS URL every 60s, logs next to the exe, exits with code 1 if status ≠ 200 |

## CI (GitHub Actions)

On push/PR to `master`:

1. **test** - restore, build, test  
2. **package** - publish HelloWorld and upload as artifact  
3. **docker** - build image; on push to `master`, push to [dhriguette/helloworld](https://hub.docker.com/r/dhriguette/helloworld)

## Deploy (run elevated PowerShell on Windows)

**Prerequisites:** .NET 10 SDK, IIS + ASP.NET Core Hosting Bundle, Docker Desktop (optional).

```powershell
# 1) Publish API, then IIS (creates group/user, site, HTTPS, app pool, /HelloWorld app)
dotnet publish .\src\HelloWorld\HelloWorld.csproj -c Release -o C:\publish\HelloWorld
.\scripts\Deploy-IIS.ps1 -SourcePath "C:\publish\HelloWorld" -Password "<password>"
# URL: http://localhost:8080/HelloWorld/health

# 2) Publish status service, then install as Windows Service
#    (local user + Carbon.Security for Log on as a service; Automatic; up to 3 restarts after 300s)
dotnet publish .\src\StatusService\StatusService.csproj -c Release -o C:\Services\StatusService
.\scripts\Deploy-WindowsService.ps1 -ExePath "C:\Services\StatusService\StatusService.exe" -Password "<password>"

# 3) Docker (optional) - do not use host port 8080 while IIS is bound to it
.\scripts\Deploy-Docker.ps1 -Image "dhriguette/helloworld:latest" -HostPort 9080
# URL: http://localhost:9080/health
```

Passwords are script parameters only - not stored in the repo. Docker Hub credentials live in GitHub Actions secrets (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`).

## Notes

- HTTPS on IIS uses a local self-signed certificate (demo only).  
- Status service recovery: exits with code 1 when HTTP status check is **not** 200 (OK); Service restarts up to 3 times, waiting 300 seconds each time (`sc failure`).  
- Scripts: `scripts/Deploy-IIS.ps1`, `Deploy-WindowsService.ps1`, `Deploy-Docker.ps1`.
