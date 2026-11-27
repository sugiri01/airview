# READ-ONLY health report for the OMPOI server (root@69.62.73.115).
#
# Run on the PC that has SSH access:
#   powershell -ExecutionPolicy Bypass -File scripts\server-health-readonly.ps1
#
# SAFETY: every command below only READS information. Nothing is started, stopped,
# restarted, installed, edited or deleted, and no file is written on the server.
# The report is saved on THIS PC (Desktop\ompoi-server-report-<time>.txt).
# Passwords/tokens/keys that appear in program command lines are masked as ***.

$ErrorActionPreference = 'Continue'
$Server = 'root@69.62.73.115'
$Out = Join-Path ([Environment]::GetFolderPath('Desktop')) ("ompoi-server-report-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmm'))

$remote = @'
mask() { sed -E 's/((pass(word|wd)?|token|secret|api[_-]?key|key|pwd)[=: ]+)[^ ,;"]+/\1***/Ig'; }
sec() { printf '\n==================== %s ====================\n' "$1"; }

sec "1. SERVER";            hostname; uptime; echo "CPU cores: $(nproc)"; cat /etc/os-release 2>/dev/null | grep -E '^PRETTY_NAME'
sec "2. MEMORY";            free -h; echo; swapon --show 2>/dev/null
sec "3. MEMORY BY PROGRAM (MB, all processes of the same program added up)"
ps -eo rss=,comm= | awk '{m[$2]+=$1; n[$2]++} END {for (p in m) printf "%8.0f MB  %4d procs  %s\n", m[p]/1024, n[p], p}' | sort -rn | head -30
sec "4. MEMORY BY USER (MB)"
ps -eo rss=,user= | awk '{m[$2]+=$1} END {for (u in m) printf "%8.0f MB  %s\n", m[u]/1024, u}' | sort -rn | head -20
sec "5. TOP 30 PROCESSES BY MEMORY"
ps -eo pid,user,%cpu,%mem,rss,etime,args --sort=-rss | head -31 | cut -c1-220 | mask
sec "6. TOP 20 PROCESSES BY CPU"
ps -eo pid,user,%cpu,%mem,etime,args --sort=-%cpu | head -21 | cut -c1-220 | mask
sec "7. CPU / MEMORY ACTIVITY (5 samples, 1s apart)"; vmstat 1 5
sec "8. DOCKER CONTAINERS"
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>&1
echo; docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' 2>&1
sec "9. OLLAMA MODELS (loaded in memory / installed)"
command -v ollama >/dev/null && { ollama ps 2>&1; echo; ollama list 2>&1; } || echo "ollama not found"
sec "10. RUNNING SERVICES"; systemctl list-units --type=service --state=running --no-pager --no-legend 2>&1 | awk '{print $1}'
sec "11. LISTENING PORTS (who listens where)"; ss -tlnp 2>&1 | cut -c1-200
sec "12. WEBSITES"
echo "-- Caddy sites:"; grep -hE '^[^#[:space:]].*\{' /etc/caddy/Caddyfile /etc/caddy/*.caddy 2>/dev/null
echo "-- /var/www folders (size):"; nice -n 19 du -sh /var/www/* 2>/dev/null | sort -rh | head -40
sec "13. DISK"; df -h -x tmpfs -x devtmpfs 2>&1
sec "14. SCHEDULED JOBS"
echo "-- root crontab:"; crontab -l 2>&1 | grep -v '^#' | mask
echo "-- /etc/cron.d:"; ls /etc/cron.d 2>&1
sec "15. OUT-OF-MEMORY EVENTS (last 14 days)"
journalctl -k --since "14 days ago" --no-pager 2>/dev/null | grep -iE 'out of memory|oom-kill|killed process' | tail -20 || true
echo "(end of OOM list)"
sec "16. CONTROL PANEL"; [ -d /usr/local/cpanel ] && echo "cPanel installed: $(cat /usr/local/cpanel/version 2>/dev/null)" || echo "no cPanel"
sec "END"
'@
$remote = $remote.Replace("`r", '')
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remote))

Write-Host "Collecting a READ-ONLY report from the server (about 15 seconds)..." -ForegroundColor Cyan
& ssh -o BatchMode=yes $Server "echo $b64 | base64 -d | bash" 2>&1 | Where-Object { $_ -notmatch 'post-quantum|store now|openssh.com/pq' } | Out-File -Encoding utf8 $Out
if ($LASTEXITCODE -ne 0) { Write-Host "SSH failed - nothing was changed on the server." -ForegroundColor Red; exit 1 }
Write-Host "Report saved to: $Out" -ForegroundColor Green
Write-Host "Send that file (or paste its contents) to Claude for the analysis."
notepad $Out
