# Updates both digital cards (approved by Sudhir on 27 Nov 2026):
#   Kadar  (https://ompoi.com/card/)        light design, name "J Kadar Oli", ompoi.com landscape behind photo
#   Sudhir (https://ompoi.com/card/sudhir/) ompoi.com landscape behind photo (nothing else)
#
# Run on the PC that has SSH access to the server:
#   powershell -ExecutionPolicy Bypass -File scripts\update-cards-landscape.ps1
#
# PRODUCTION SAFETY - what this script does on the server, and nothing else:
#   * REPLACES 3 files we created:  card/index.html, card/kadar-oli.vcf, card/sudhir/index.html
#   * ADDS 2 new image files:       card/ompoi-hero.jpg, card/sudhir/ompoi-hero.jpg
#   * First copies the 3 old files to a NEW backup folder outside the website
#     (/root/ompoi-card-backups/cards-<date-time>/) so everything can be undone.
#   * Fingerprints EVERY other file of the website before and after (including the other
#     card files) and tells you if anything else changed.
#   * Never touches Caddy, other sites, services, processes, ports or packages; restarts nothing.

$ErrorActionPreference = 'Continue'   # ssh/scp write to stderr; exit codes are checked
$Server = 'root@69.62.73.115'
$Site   = '/var/www/ompoi-website-v07'
$Card   = "$Site/card"
$Stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = "/root/ompoi-card-backups/cards-$Stamp"
$Root   = Join-Path $PSScriptRoot '..\card'
$Replace = @('index.html','kadar-oli.vcf','sudhir/index.html')
$Add     = @('ompoi-hero.jpg','sudhir/ompoi-hero.jpg')
$Touched = $Replace + $Add

function Stop-Here($msg) { Write-Host "`nSTOPPED: $msg" -ForegroundColor Red; exit 1 }

Write-Host "`n== 1/5  Checking the new files on this PC ==" -ForegroundColor Cyan
foreach ($f in $Touched) { if (-not (Test-Path (Join-Path $Root $f))) { Stop-Here "missing card\$f - run 'git pull' first. Nothing was changed on the server." } }
$k = Get-Content (Join-Path $Root 'index.html') -Raw
$s = Get-Content (Join-Path $Root 'sudhir\index.html') -Raw
if ($k -notmatch 'J Kadar Oli' -or $k -notmatch 'ompoi-hero.jpg' -or $s -notmatch 'ompoi-hero.jpg') { Stop-Here "local files are not the updated version - run 'git pull' first. Nothing was changed." }
Write-Host "Updated files found."

Write-Host "`n== 2/5  Safety checks on the server (read-only) ==" -ForegroundColor Cyan
$check = & ssh -o BatchMode=yes $Server "cd '$Card' || echo NO_CARD; for f in index.html kadar-oli.vcf sudhir/index.html; do [ -f `$f ] || echo MISSING_`$f; done; for f in ompoi-hero.jpg sudhir/ompoi-hero.jpg; do [ -e `$f ] && echo EXISTS_`$f; done; [ -e '$Backup' ] && echo BACKUP_EXISTS; echo DONE"
if ($LASTEXITCODE -ne 0) { Stop-Here "could not connect with SSH. Nothing was changed." }
if ($check -match 'NO_CARD|MISSING_')  { Stop-Here "the card files are not where expected ($check). Nothing was changed." }
if ($check -match 'EXISTS_')           { Stop-Here "a new image already exists on the server ($check). Nothing was changed." }
if ($check -match 'BACKUP_EXISTS')     { Stop-Here "backup folder already exists. Nothing was changed." }
Write-Host "OK: card files found, new image names are free."

# Fingerprint of every website file EXCEPT the 5 files this script replaces/adds
$excl = ($Touched | ForEach-Object { "! -path '$Card/$_'" }) -join ' '
$fp = "find '$Site' -type f $excl -printf '%p %s %T@ %m %u\n' | sort | sha256sum | cut -c1-64"
$before = (& ssh -o BatchMode=yes $Server $fp | Out-String).Trim()
if ($before.Length -ne 64) { Stop-Here "could not take the before-fingerprint. Nothing was changed." }
Write-Host "Fingerprint of all other website files taken."

Write-Host "`n== 3/5  Backing up, then updating the cards ==" -ForegroundColor Cyan
& ssh -o BatchMode=yes $Server "mkdir -p '$Backup/sudhir' && cp -p '$Card/index.html' '$Card/kadar-oli.vcf' '$Backup/' && cp -p '$Card/sudhir/index.html' '$Backup/sudhir/'"
if ($LASTEXITCODE -ne 0) { Stop-Here "backup failed. The cards were NOT changed." }
Write-Host "Backup saved to $Backup"
& scp -q -o BatchMode=yes (Join-Path $Root 'index.html') (Join-Path $Root 'kadar-oli.vcf') (Join-Path $Root 'ompoi-hero.jpg') "${Server}:$Card/"
$ok1 = $LASTEXITCODE
& scp -q -o BatchMode=yes (Join-Path $Root 'sudhir\index.html') (Join-Path $Root 'sudhir\ompoi-hero.jpg') "${Server}:$Card/sudhir/"
if ($ok1 -ne 0 -or $LASTEXITCODE -ne 0) { Stop-Here "copy failed. To restore: ssh $Server `"cp -p $Backup/index.html $Backup/kadar-oli.vcf $Card/ && cp -p $Backup/sudhir/index.html $Card/sudhir/`"" }
$list = ($Touched | ForEach-Object { "'$Card/$_'" }) -join ' '
& ssh -o BatchMode=yes $Server "chown pakchoi:root $list && chmod 644 $list"
Write-Host "Cards updated."

Write-Host "`n== 4/5  Confirming nothing else changed ==" -ForegroundColor Cyan
$after = (& ssh -o BatchMode=yes $Server $fp | Out-String).Trim()
if ($after -eq $before) { Write-Host "OK: every other website file is exactly as before." -ForegroundColor Green }
else { Write-Host "WARNING: a file outside the 5 card files changed. This can also happen if someone else edited the site at the same moment. Tell Claude before doing anything else." -ForegroundColor Yellow }

Write-Host "`n== 5/5  Checking the pages load ==" -ForegroundColor Cyan
foreach ($u in @('https://ompoi.com/card/','https://ompoi.com/card/ompoi-hero.jpg','https://ompoi.com/card/sudhir/','https://ompoi.com/card/sudhir/ompoi-hero.jpg','https://ompoi.com/')) {
    try { $code = (Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 20).StatusCode } catch { $code = $_.Exception.Response.StatusCode.value__ }
    Write-Host ("{0}  {1}" -f $code, $u)
}
Write-Host "`nDone. Undo if ever needed:" -ForegroundColor Green
Write-Host "  ssh $Server `"cp -p $Backup/index.html $Backup/kadar-oli.vcf $Card/ && cp -p $Backup/sudhir/index.html $Card/sudhir/`""
