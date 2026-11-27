# Runs the OMPOI Price forecasting system LOCALLY on this Windows laptop, for testing.
# Uses the built-in synthetic demo: no Docker, no API keys, no server, nothing online.
#
#   powershell -ExecutionPolicy Bypass -File scripts\run-price-local.ps1          # start (first run sets up)
#   powershell -ExecutionPolicy Bypass -File scripts\run-price-local.ps1 -Reset   # rebuild demo data from scratch
#
# Opens: dashboard http://localhost:8501, monitoring http://localhost:8502, API docs http://localhost:8001/docs
# To stop: close the three PowerShell windows it opens.
# Everything lives in %USERPROFILE%\ompoi-price-local. Delete that folder to remove it completely.

param([switch]$Reset)
$ErrorActionPreference = 'Stop'
$Home2  = Join-Path $env:USERPROFILE 'ompoi-price-local'
$Repo   = 'https://github.com/sugiri01/Ompoi_price_pred.git'
$Branch = 'ccr-fe28f715-2nywa4'

function Step($m) { Write-Host "`n== $m ==" -ForegroundColor Cyan }

Step "1/5  Checking tools"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git is not installed. Install from https://git-scm.com and run again." }
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing 'uv' (Python package manager, also fetches Python 3.11 for you)..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { throw "uv install failed. Install it from https://docs.astral.sh/uv/ and run again." }
}
Write-Host "git and uv OK"

Step "2/5  Getting the code"
if (Test-Path (Join-Path $Home2 '.git')) {
    git -C $Home2 pull --ff-only
} else {
    git clone -b $Branch $Repo $Home2
}
Set-Location $Home2

Step "3/5  Python environment (first time: a few minutes)"
if (-not (Test-Path '.venv')) { uv venv -p 3.11 .venv }
uv pip install -p .venv -e ".[dev,dashboard]"
$Bin = Join-Path $Home2 '.venv\Scripts'

Step "4/5  Demo data and first model"
if ($Reset) { Remove-Item -Force -ErrorAction SilentlyContinue ompoi.db, mlflow.db; Remove-Item -Recurse -Force -ErrorAction SilentlyContinue mlartifacts }
if (-not (Test-Path 'ompoi.db')) {
    Write-Host "Creating SYNTHETIC history, training and forecasting (about 5-10 minutes)..."
    & "$Bin\ompoi.exe" demo --start 2021-01-01 --folds 12
    if ($LASTEXITCODE -ne 0) { throw "Demo failed - send the error above to Claude." }
} else { Write-Host "Demo data already exists (use -Reset to rebuild)." }

Step "5/5  Starting API, dashboard and monitoring (3 windows)"
$cd = "Set-Location '$Home2'"
Start-Process powershell -ArgumentList '-NoExit','-Command',"$cd; `$host.UI.RawUI.WindowTitle='OMPOI API :8001'; & '$Bin\uvicorn.exe' api.application:get_app --factory --port 8001"
Start-Sleep 3
Start-Process powershell -ArgumentList '-NoExit','-Command',"$cd; `$host.UI.RawUI.WindowTitle='OMPOI Dashboard :8501'; & '$Bin\streamlit.exe' run app-frontend/frontend/main.py --server.port 8501 --server.headless true"
Start-Process powershell -ArgumentList '-NoExit','-Command',"$cd; `$host.UI.RawUI.WindowTitle='OMPOI Monitoring :8502'; `$env:PYTHONPATH='app-frontend'; & '$Bin\streamlit.exe' run app-monitoring/monitoring_app/main.py --server.port 8502 --server.headless true"
Start-Sleep 8
Start-Process 'http://localhost:8501'

Write-Host "`nRunning locally on this laptop:" -ForegroundColor Green
Write-Host "  Dashboard   http://localhost:8501"
Write-Host "  Monitoring  http://localhost:8502"
Write-Host "  API docs    http://localhost:8001/docs"
Write-Host "NOTE: all prices are SYNTHETIC demo data, not real market data."
Write-Host "Stop: close the three 'OMPOI' PowerShell windows."
