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
- card/        -> https://ompoi.com/card/         (Kadar Oli, Founder & CEO, auto light/dark). Live; do not change unless asked.
- card/sudhir/ -> https://ompoi.com/card/sudhir/  (Sudhir Giri, Co-Founder & CTO, light only). Live since 27 Nov 2026 (uploaded with scripts/upload-sudhir-card.ps1)
- Static assets are cached for 1 year by Caddy: a changed image needs a new file name.

## Google Drive status — ALWAYS keep updated
The user checks ONLY Google Drive for status, not Claude Code.
- Folder: "OMPOI - Work & Status (Cards, Server, Price system)"
  https://drive.google.com/drive/folders/1lNaEYXcHoVrw9inSo55F5OG2jUHCzIMC
- Status page (update after EVERY change, decision or new finding, including
  the "Last updated" line, status board, decisions waiting and next commands):
  "00 - START HERE - OMPOI Current Status"
  https://docs.google.com/document/d/1aMzGvhhUhniHhNzjYxMF_D8TO9awkC7ZOcsuKS9kqsM/edit
- Detail docs in the same folder: Cards Work Summary (1gCJuAKePE6oOH0S43mopoBJnDd4bKWuRWMLszp4dSFI),
  Server Health Check (1Y2WkrSA7q1voEMosbIZJHFBovv-8F8_aikc_YtCYVYw).
