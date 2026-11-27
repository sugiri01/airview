# One-time setup: lets GitHub upload the OMPOI card to https://ompoi.com/card/
# automatically, so you never have to run upload commands on this PC again.
#
# Run once on the PC that already has SSH access to the server:
#   powershell -ExecutionPolicy Bypass -File scripts\setup-card-deploy.ps1
#
# What it changes on the server (and nothing else):
#   - Adds ONE line to /root/.ssh/authorized_keys (a backup is made first).
#     That line is a new key that is locked to "rsync into
#     /var/www/ompoi-website-v07/card only": it cannot open a shell, run
#     commands, forward ports, or reach any other folder, site or service.
#   - No services are restarted, no packages installed, no other files touched.
# If anything needed is missing, it stops and changes nothing.

$ErrorActionPreference = 'Continue'   # native ssh writes to stderr; we check exit codes ourselves
$Server  = 'root@69.62.73.115'
$HostIP  = '69.62.73.115'
$CardDir = '/var/www/ompoi-website-v07/card'
$Repo    = 'sugiri01/airview'
$KeyFile = Join-Path $env:USERPROFILE '.ssh\ompoi_card_deploy'

Write-Host "`n== 1/4  Creating a new deploy key (used only for the card) ==" -ForegroundColor Cyan
if (-not (Test-Path $KeyFile)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $KeyFile) | Out-Null
    # cmd.exe passes "" as a true empty passphrase on every PowerShell version
    & cmd /c "ssh-keygen -q -t ed25519 -N `"`" -C ompoi-card-deploy -f `"$KeyFile`""
    if (-not (Test-Path $KeyFile)) { throw "ssh-keygen failed to create $KeyFile" }
} else { Write-Host "Key already exists, reusing $KeyFile" }
$Pub = (Get-Content "$KeyFile.pub" -Raw).Trim()
if ($Pub -notmatch '^ssh-ed25519 [A-Za-z0-9+/=]+ ompoi-card-deploy$') { throw "Unexpected public key format: $Pub" }

Write-Host "`n== 2/4  Installing the locked-down key on the server ==" -ForegroundColor Cyan
$remote = @'
set -eu
DIR="__DIR__"
PUB="__PUB__"
[ -d "$DIR" ] || { echo "STOP: $DIR does not exist. Nothing changed."; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "STOP: rsync is not installed on the server. Nothing changed."; exit 1; }
RR="$(command -v rrsync 2>/dev/null || true)"
[ -z "$RR" ] && [ -x /usr/share/doc/rsync/scripts/rrsync ] && RR=/usr/share/doc/rsync/scripts/rrsync
[ -n "$RR" ] || { echo "STOP: rrsync (the rsync folder-lock helper) was not found. Nothing changed."; exit 1; }
AK=/root/.ssh/authorized_keys
if grep -qF "ompoi-card-deploy" "$AK" 2>/dev/null; then
  echo "Deploy key already installed - nothing changed."
else
  cp -p "$AK" "$AK.bak-$(date +%Y%m%d-%H%M%S)"
  printf '%s\n' "command=\"$RR $DIR\",restrict $PUB" >> "$AK"
  echo "Installed locked-down deploy key (backup of authorized_keys saved next to it)."
fi
'@
$remote = $remote.Replace('__DIR__', $CardDir).Replace('__PUB__', $Pub).Replace("`r", '')
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remote))
& ssh -o BatchMode=yes $Server "echo $b64 | base64 -d | bash"
if ($LASTEXITCODE -ne 0) { throw "Server step stopped (see message above). Nothing else was done." }

Write-Host "`n== 3/4  Checking the new key is locked down ==" -ForegroundColor Cyan
$out = & ssh -o BatchMode=yes -o IdentitiesOnly=yes -i $KeyFile $Server 'ls /' 2>&1 | Out-String
if ($out -match 'Permission denied') { throw "The server did not accept the new key. Check the 'ompoi-card-deploy' line in /root/.ssh/authorized_keys." }
if ($out -match '(?m)^(bin|etc|home|var|usr)\s*$') { throw "WARNING: the new key could run a command. Remove the 'ompoi-card-deploy' line from /root/.ssh/authorized_keys." }
Write-Host "Good: the new key cannot run commands (server replied: $($out.Trim()))"

Write-Host "`n== 4/4  Saving the key as GitHub secrets ==" -ForegroundColor Cyan
$known = (& ssh-keyscan -t ed25519 $HostIP 2>$null | Out-String).Trim()
if (-not $known) { throw "Could not read the server's host key with ssh-keyscan." }
$priv = Get-Content $KeyFile -Raw

if (Get-Command gh -ErrorAction SilentlyContinue) {
    $priv  | & gh secret set CARD_DEPLOY_KEY -R $Repo
    $known | & gh secret set CARD_DEPLOY_KNOWN_HOSTS -R $Repo
    Write-Host "Secrets saved to github.com/$Repo with the gh tool." -ForegroundColor Green
} else {
    Write-Host "The GitHub 'gh' tool isn't installed, so add 2 secrets by hand:" -ForegroundColor Yellow
    Write-Host "  Open: https://github.com/$Repo/settings/secrets/actions  ->  'New repository secret'"
    Set-Clipboard -Value $priv
    Write-Host "  1) Name: CARD_DEPLOY_KEY          Value: (already copied to your clipboard - just paste)"
    Read-Host  "     Press Enter after saving CARD_DEPLOY_KEY"
    Set-Clipboard -Value $known
    Write-Host "  2) Name: CARD_DEPLOY_KNOWN_HOSTS  Value: (now copied to your clipboard - just paste)"
    Read-Host  "     Press Enter after saving CARD_DEPLOY_KNOWN_HOSTS"
    Set-Clipboard -Value ' '
}

Write-Host "`nDone. From now on, any change to card/ pushed to GitHub is uploaded to https://ompoi.com/card/ automatically." -ForegroundColor Green
Write-Host "To undo at any time: delete the line containing 'ompoi-card-deploy' from /root/.ssh/authorized_keys on the server."
