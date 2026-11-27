# Working rules for this repo

## OMPOI production server — strict rules
The server (root@69.62.73.115, Caddy, site root /var/www/ompoi-website-v07) is a
PRODUCTION server running many sites, programs and ports.

- Claude never connects to the server. Claude prepares files in this repo and
  gives the user a script; the user runs it from their PC.
- Scripts may ONLY add new files in a NEW folder. Never edit, overwrite, delete,
  move, chown/chmod existing files, never touch Caddy/nginx config, services,
  processes, ports, firewall or packages, never restart or reload anything.
- Every upload script must first check the target folder does not exist and
  stop (changing nothing) if it does.
- After the user uploads, verify from outside (curl) that the new page works
  and that existing pages (e.g. https://ompoi.com/) are unchanged.

## Digital cards
- card/  -> https://ompoi.com/card/  (Kadar Oli, Founder & CEO). Live; do not change unless asked.
- Static assets are cached for 1 year by Caddy: a changed image needs a new file name.
