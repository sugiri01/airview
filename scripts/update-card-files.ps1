# Replaces named files of OUR digital cards on the OMPOI server (reusable for small card edits).
#
# Example (27 Nov 2026 - Kadar's LinkedIn):
#   powershell -ExecutionPolicy Bypass -File scripts\update-card-files.ps1 -Files index.html,kadar-oli.vcf
#   (paths are relative to the card folder; Sudhir's files are e.g. sudhir/index.html)
#
# PRODUCTION SAFETY - what this script does on the server, and nothing else:
#   * Only works inside /var/www/ompoi-website-v07/card. Refuses any path with '..', '\' at the
#     start, or outside the card folder.
#   * Only REPLACES files that already exist there (never adds or deletes anything).
#   * First copies the old versions to a NEW backup folder outside the website
#     (/root/ompoi-card-backups/files-<date-time>/), and prints the undo command.
#   * Fingerprints EVERY other website file before and after and tells you if anything else changed.
#   * Never touches Caddy, other sites, services, processes, ports or packages; restarts nothing.

param([Parameter(Mandatory=$true)][string[]]$Files)
$ErrorActionPreference = 'Continue'   # ssh/scp write to stderr; exit codes are checked
$Server = 'root@69.62.73.115'
$Site   = '/var/www/ompoi-website-v07'
$Card   = "$Site/card"
$Stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = "/root/ompoi-card-backups/files-$Stamp"
$Root   = Join-Path $PSScriptRoot '..\card'

function Stop-Here($msg) { Write-Host "`nSTOPPED: $msg" -ForegroundColor Red; exit 1 }

Write-Host "`n== 1/5  Checking the files on this PC ==" -ForegroundColor Cyan
$Files = $Files | ForEach-Object { $_.Trim().Replace('\','/') } | Where-Object { $_ }
foreach ($f in $Files) {
    if ($f -notmatch '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)?$' -or $f -match '\.\.') { Stop-Here "'$f' is not a plain card file path. Nothing was changed." }
    if (-not (Test-Path (Join-Path $Root $f))) { Stop-Here "missing card\$f on this PC - run 'git pull' first. Nothing was changed." }
}
Write-Host ("Files to replace: " + ($Files -join ', '))

Write-Host "`n== 2/5  Safety checks on the server (read-only) ==" -ForegroundColor Cyan
$names = ($Files | ForEach-Object { "'$_'" }) -join ' '
$check = & ssh -o BatchMode=yes $Server "cd '$Card' || echo NO_CARD; for f in $names; do [ -f `"`$f`" ] || echo MISSING_`$f; done; [ -e '$Backup' ] && echo BACKUP_EXISTS; echo DONE"
if ($LASTEXITCODE -ne 0) { Stop-Here "could not connect with SSH. Nothing was changed." }
if ($check -match 'NO_CARD|MISSING_') { Stop-Here "not found on the server ($check). This script only replaces existing card files. Nothing was changed." }
if ($check -match 'BACKUP_EXISTS')    { Stop-Here "backup folder already exists. Nothing was changed." }
Write-Host "OK: all files exist on the server."

$excl = ($Files | ForEach-Object { "! -path '$Card/$_'" }) -join ' '
$fp = "find '$Site' -type f $excl -printf '%p %s %T@ %m %u\n' | sort | sha256sum | cut -c1-64"
$before = (& ssh -o BatchMode=yes $Server $fp | Out-String).Trim()
if ($before.Length -ne 64) { Stop-Here "could not take the before-fingerprint. Nothing was changed." }
Write-Host "Fingerprint of all other website files taken."

Write-Host "`n== 3/5  Backing up, then replacing ==" -ForegroundColor Cyan
& ssh -o BatchMode=yes $Server "cd '$Card' && mkdir -p '$Backup' && cp -p --parents $names '$Backup/'"
if ($LASTEXITCODE -ne 0) { Stop-Here "backup failed. Nothing was replaced." }
Write-Host "Backup saved to $Backup"
foreach ($f in $Files) {
    & scp -q -o BatchMode=yes (Join-Path $Root $f) "${Server}:$Card/$f"
    if ($LASTEXITCODE -ne 0) { Stop-Here "copy of $f failed. Undo: ssh $Server `"cd $Backup && cp -p --parents $names $Card/`"" }
}
$list = ($Files | ForEach-Object { "'$Card/$_'" }) -join ' '
& ssh -o BatchMode=yes $Server "chown pakchoi:root $list && chmod 644 $list"
Write-Host "Replaced."

Write-Host "`n== 4/5  Confirming nothing else changed ==" -ForegroundColor Cyan
$after = (& ssh -o BatchMode=yes $Server $fp | Out-String).Trim()
if ($after -eq $before) { Write-Host "OK: every other website file is exactly as before." -ForegroundColor Green }
else { Write-Host "WARNING: a file outside the replaced card files changed. This can also happen if someone else edited the site at the same moment. Tell Claude before doing anything else." -ForegroundColor Yellow }

Write-Host "`n== 5/5  Checking the pages load ==" -ForegroundColor Cyan
foreach ($u in @('https://ompoi.com/card/','https://ompoi.com/card/sudhir/','https://ompoi.com/')) {
    try { $code = (Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 20).StatusCode } catch { $code = $_.Exception.Response.StatusCode.value__ }
    Write-Host ("{0}  {1}" -f $code, $u)
}
Write-Host "`nDone. Undo if ever needed:" -ForegroundColor Green
Write-Host "  ssh $Server `"cd $Backup && cp -p --parents $names $Card/`""
