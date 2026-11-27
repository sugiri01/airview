# Adds Sudhir Giri's digital card to the OMPOI server at https://ompoi.com/card/sudhir/
#
# Run on the PC that has SSH access to the server:
#   powershell -ExecutionPolicy Bypass -File scripts\upload-sudhir-card.ps1
#
# PRODUCTION SAFETY - what this script does on the server, and nothing else:
#   * Creates ONE new folder: /var/www/ompoi-website-v07/card/sudhir
#   * Copies 6 new files into it and sets permissions on that new folder only.
#   * Stops BEFORE changing anything if that folder already exists.
#   * Never edits, overwrites, deletes or moves an existing file, and never
#     touches Caddy, other sites, services, processes, ports or packages.
#   * Fingerprints every existing file of the website before and after, and
#     tells you if anything other than the new folder changed.

$ErrorActionPreference = 'Continue'   # ssh/scp write to stderr; exit codes are checked
$Server = 'root@69.62.73.115'
$Site   = '/var/www/ompoi-website-v07'
$Parent = "$Site/card"
$Target = "$Parent/sudhir"
$Files  = @('index.html','sudhir.jpg','sudhir-giri.vcf','qr.png','ompoi-logo.png','ompoi-mark.png')
$Src    = Join-Path $PSScriptRoot '..\card\sudhir'

function Stop-Here($msg) { Write-Host "`nSTOPPED: $msg" -ForegroundColor Red; exit 1 }

Write-Host "`n== 1/5  Checking the files on this PC ==" -ForegroundColor Cyan
foreach ($f in $Files) { if (-not (Test-Path (Join-Path $Src $f))) { Stop-Here "missing $Src\$f - run 'git pull' first. Nothing was changed on the server." } }
Write-Host "All 6 files found in $Src"

Write-Host "`n== 2/5  Safety checks on the server (read-only) ==" -ForegroundColor Cyan
$check = & ssh -o BatchMode=yes $Server "if [ ! -d '$Parent' ]; then echo NO_PARENT; elif [ -e '$Target' ]; then echo EXISTS; else echo OK; fi"
if ($LASTEXITCODE -ne 0) { Stop-Here "could not connect with SSH. Nothing was changed." }
if ($check -match 'NO_PARENT') { Stop-Here "$Parent does not exist on the server. Nothing was changed." }
if ($check -match 'EXISTS')    { Stop-Here "$Target already exists. Nothing was changed (this script never overwrites)." }
Write-Host "OK: $Target does not exist yet."

# Fingerprint of every existing website file (path, size, modified time), excluding the new folder
$fp = "find '$Site' -path '$Target' -prune -o -type f -printf '%p %s %T@ %m %u\n' | sort | sha256sum | cut -c1-64"
$before = (& ssh -o BatchMode=yes $Server $fp | Out-String).Trim()
if ($before.Length -ne 64) { Stop-Here "could not take the before-fingerprint. Nothing was changed." }
Write-Host "Fingerprint of existing site files taken."

Write-Host "`n== 3/5  Adding the new folder and files ==" -ForegroundColor Cyan
& ssh -o BatchMode=yes $Server "mkdir '$Target'"
if ($LASTEXITCODE -ne 0) { Stop-Here "could not create $Target." }
$paths = $Files | ForEach-Object { Join-Path $Src $_ }
& scp -q -o BatchMode=yes @paths "${Server}:$Target/"
if ($LASTEXITCODE -ne 0) { Stop-Here "copy failed. Only the new folder $Target may exist - nothing else was touched." }
& ssh -o BatchMode=yes $Server "chown -R pakchoi:root '$Target' && chmod 755 '$Target' && chmod 644 '$Target'/*"
Write-Host "Added $Target with $($Files.Count) files."

Write-Host "`n== 4/5  Confirming nothing else changed ==" -ForegroundColor Cyan
$after = (& ssh -o BatchMode=yes $Server $fp | Out-String).Trim()
if ($after -eq $before) { Write-Host "OK: every existing website file is exactly as before." -ForegroundColor Green }
else { Write-Host "WARNING: the site fingerprint changed. This can also happen if someone else edited the site at the same moment. Tell Claude before doing anything else." -ForegroundColor Yellow }

Write-Host "`n== 5/5  Checking the pages load ==" -ForegroundColor Cyan
foreach ($u in @('https://ompoi.com/card/sudhir/','https://ompoi.com/card/sudhir/sudhir-giri.vcf','https://ompoi.com/card/','https://ompoi.com/')) {
    try { $code = (Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 20).StatusCode } catch { $code = $_.Exception.Response.StatusCode.value__ }
    Write-Host ("{0}  {1}" -f $code, $u)
}
Write-Host "`nDone. Sudhir's card: https://ompoi.com/card/sudhir/" -ForegroundColor Green
