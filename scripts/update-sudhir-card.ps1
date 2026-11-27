# PENDING USER APPROVAL: replaces 2 existing files (our own) in card/sudhir, which the
# strict server rule in CLAUDE.md does not yet allow. Do not run until the user approves.
#
# Updates Sudhir Giri's card at https://ompoi.com/card/sudhir/ (new phone number, Mensa removed)
#
# Run on the PC that has SSH access to the server:
#   powershell -ExecutionPolicy Bypass -File scripts\update-sudhir-card.ps1
#
# PRODUCTION SAFETY - what this script does on the server, and nothing else:
#   * Replaces exactly 2 files that WE created inside /var/www/ompoi-website-v07/card/sudhir:
#       index.html, sudhir-giri.vcf
#   * First copies the current versions to a NEW backup folder outside the website:
#       /root/ompoi-card-backups/sudhir-<date-time>/   (so the change can be undone)
#   * Never touches any other file, folder, site, Caddy, service, process, port or package,
#     and never restarts anything.
#   * Fingerprints every other website file before and after, and tells you if anything
#     outside card/sudhir changed.

$ErrorActionPreference = 'Continue'   # ssh/scp write to stderr; exit codes are checked
$Server = 'root@69.62.73.115'
$Site   = '/var/www/ompoi-website-v07'
$Target = "$Site/card/sudhir"
$Files  = @('index.html','sudhir-giri.vcf')
$Src    = Join-Path $PSScriptRoot '..\card\sudhir'
$Stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = "/root/ompoi-card-backups/sudhir-$Stamp"

function Stop-Here($msg) { Write-Host "`nSTOPPED: $msg" -ForegroundColor Red; exit 1 }

Write-Host "`n== 1/5  Checking the new files on this PC ==" -ForegroundColor Cyan
foreach ($f in $Files) { if (-not (Test-Path (Join-Path $Src $f))) { Stop-Here "missing $Src\$f - run 'git pull' first. Nothing was changed on the server." } }
$html = Get-Content (Join-Path $Src 'index.html') -Raw
if ($html -notmatch '919840347570' -or $html -match 'Mensa') { Stop-Here "local index.html is not the updated version - run 'git pull' first. Nothing was changed." }
Write-Host "Updated files found (new number, no Mensa)."

Write-Host "`n== 2/5  Safety checks on the server (read-only) ==" -ForegroundColor Cyan
$check = & ssh -o BatchMode=yes $Server "for f in index.html sudhir-giri.vcf; do [ -f '$Target'/`$f ] || echo MISSING; done; [ -e '$Backup' ] && echo BACKUP_EXISTS; echo DONE"
if ($LASTEXITCODE -ne 0) { Stop-Here "could not connect with SSH. Nothing was changed." }
if ($check -match 'MISSING')       { Stop-Here "Sudhir's card files are not on the server at $Target. Nothing was changed." }
if ($check -match 'BACKUP_EXISTS') { Stop-Here "backup folder $Backup already exists. Nothing was changed." }
Write-Host "OK: Sudhir's card found."

$fp = "find '$Site' -path '$Target' -prune -o -type f -printf '%p %s %T@ %m %u\n' | sort | sha256sum | cut -c1-64"
$before = (& ssh -o BatchMode=yes $Server $fp | Out-String).Trim()
if ($before.Length -ne 64) { Stop-Here "could not take the before-fingerprint. Nothing was changed." }
Write-Host "Fingerprint of all other site files taken."

Write-Host "`n== 3/5  Backing up, then replacing the 2 files ==" -ForegroundColor Cyan
& ssh -o BatchMode=yes $Server "mkdir -p '$Backup' && cp -p '$Target/index.html' '$Target/sudhir-giri.vcf' '$Backup/'"
if ($LASTEXITCODE -ne 0) { Stop-Here "backup failed. The card was NOT changed." }
Write-Host "Backup saved to $Backup"
$paths = $Files | ForEach-Object { Join-Path $Src $_ }
& scp -q -o BatchMode=yes @paths "${Server}:$Target/"
if ($LASTEXITCODE -ne 0) { Stop-Here "copy failed. To restore: ssh $Server `"cp -p $Backup/* $Target/`"" }
& ssh -o BatchMode=yes $Server "chown pakchoi:root '$Target/index.html' '$Target/sudhir-giri.vcf' && chmod 644 '$Target/index.html' '$Target/sudhir-giri.vcf'"
Write-Host "Replaced index.html and sudhir-giri.vcf."

Write-Host "`n== 4/5  Confirming nothing else changed ==" -ForegroundColor Cyan
$after = (& ssh -o BatchMode=yes $Server $fp | Out-String).Trim()
if ($after -eq $before) { Write-Host "OK: every other website file is exactly as before." -ForegroundColor Green }
else { Write-Host "WARNING: a file outside card/sudhir changed. This can also happen if someone else edited the site at the same moment. Tell Claude before doing anything else." -ForegroundColor Yellow }

Write-Host "`n== 5/5  Checking the pages load ==" -ForegroundColor Cyan
foreach ($u in @('https://ompoi.com/card/sudhir/','https://ompoi.com/card/sudhir/sudhir-giri.vcf','https://ompoi.com/card/','https://ompoi.com/')) {
    try { $code = (Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 20).StatusCode } catch { $code = $_.Exception.Response.StatusCode.value__ }
    Write-Host ("{0}  {1}" -f $code, $u)
}
Write-Host "`nDone. Undo if ever needed:  ssh $Server `"cp -p $Backup/* $Target/`"" -ForegroundColor Green
