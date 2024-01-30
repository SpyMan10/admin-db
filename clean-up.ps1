# Simple script for clearing Docker MySQL container data. 

if (Test-Path "data/") {
  Write-Host ">> Stopping Docker container..." -ForegroundColor Yellow;
  $(docker compose down)
  Write-Host ">> Removing MySQL data..." -ForegroundColor Yellow;
  Remove-Item -Path "data/" -Recurse;
  Write-Host ">> Restarting Docker container..." -ForegroundColor Green;
  $(docker compose up --force-recreate --build -d);
}