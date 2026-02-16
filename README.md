# 🧱 Hetzner VPS — Docker + Caddy + Security Hardening

This README documents the current state of a hardened Hetzner VPS **before Docker stacks are brought back online**.
It is written to be:
- reproducible
- handoff-safe
- future-you friendly

You can copy this file into `/srv/docker/README.md`, keep it in a private repo, or use it to resume work after a break.

---

## ✅ Goals Achieved So Far

- Secure SSH (key-only, no root login)
- Docker standardized under `/srv/docker`
- Persistent data via bind mounts under `/srv/docker/data`
- Caddy as the **only public entry point** (80/443)
- Redis & Postgres protected from public exposure
- Internal Docker networking cleaned up
- Logging + audit strategy implemented
- Maintenance scripts created
- Global bring-up script created
- Pause point reached before enabling cron jobs

---

## 🗂️ Directory Layout

```text
/srv/docker/
├── caddy/
├── paperless-ngx/
├── immich/
├── dev-dbs/
├── n8n/
├── vaultwarden/
├── app/
└── data/
    ├── caddy_data/
    ├── caddy_config/
    ├── paperless-ngx/
    ├── immich/
    └── postgres/
```

All critical data is stored via bind mounts under `/srv/docker/data`.
No named volumes are used for important data.

---

## 🔐 SSH Hardening

### Clear old host keys (after reset)
```bash
ssh-keygen -R 157.180.37.52
```

### Create user and enable sudo
```bash
adduser alvin
usermod -aG sudo alvin
```

### SSH key setup (from macOS)
```bash
ssh-keygen -t ed25519 -C "alvin@mac"
ssh-copy-id alvin@157.180.37.52
```

### Disable root + password auth
`/etc/ssh/sshd_config`
```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

```bash
sudo systemctl restart ssh
```

---

## 🐳 Docker Installation

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker alvin
newgrp docker
```

Verify:
```bash
docker version
docker compose version
```

---

## 🌐 Docker Networking Model

Two **external** Docker networks are used:

```bash
docker network create web || true
docker network create caddy_net || true
```

### Network Purpose
| Network | Purpose |
|------|------|
| web | Public web apps behind Caddy |
| caddy_net | Cross-stack proxy (Caddy → Paperless / Immich) |

### Rules
- Only Caddy exposes public ports
- Redis & Postgres are never public
- Internal services communicate by Docker DNS

---

## 🔥 Firewall (UFW)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

sudo ufw allow OpenSSH
sudo ufw allow 80
sudo ufw allow 443

sudo ufw deny 6379/tcp
sudo ufw deny 5432/tcp
sudo ufw deny 5050/tcp

sudo ufw enable
sudo ufw status verbose
```

---

## 🧱 Caddy (Docker)

### docker-compose.yml
```yml
version: "3.9"

services:
  caddy:
    image: caddy:2
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./conf:/etc/caddy
      - ./site:/srv
      - /srv/docker/data/caddy_data:/data
      - /srv/docker/data/caddy_config:/config
    networks:
      - web
      - caddy_net

networks:
  web:
    external: true
  caddy_net:
    external: true
```

### Caddyfile
```caddy
:80 {
    root * /srv
    file_server
}

dev.kigtech.digital {
    root * /srv
    file_server
}

app.kigtech.digital {
    reverse_proxy app:3000
}

n8n.kigtech.digital {
    reverse_proxy n8n:5678
}

vault.dev.kigtech.digital {
    reverse_proxy vaultwarden:80
}

# Planned
# paperless.kigtech.digital -> paperless-ngx:8000
# immich.kigtech.digital -> immich_server:2283
```

---

## 📄 Paperless (Internal-Only)

- Redis + Postgres are internal
- Web container joins `caddy_net`
- No public port exposure

```yml
services:
  webserver:
    networks:
      - default
      - caddy_net
```

Caddy:
```caddy
paperless.kigtech.digital {
  reverse_proxy paperless-ngx:8000
}
```

---

## 🖼️ Immich (Internal-Only)

```yml
services:
  immich-server:
    networks:
      - default
      - caddy_net
```

Caddy:
```caddy
immich.kigtech.digital {
  reverse_proxy immich_server:2283
}
```

---

## 🧪 Dev Databases (Postgres + pgAdmin)

### Localhost-only binding
```yml
postgres:
  ports:
    - "127.0.0.1:5432:5432"

pgadmin:
  ports:
    - "127.0.0.1:5050:80"
```

### Remote access
```bash
ssh -N alvin@157.180.37.52 \
  -L 5432:127.0.0.1:5432 \
  -L 5050:127.0.0.1:5050
```

---

## 🚨 Redis Exposure Prevention

- No `ports: 6379`
- Firewall deny
- Kernel-level connection logging

### Redis access logs
```text
/var/log/secure-audit/redis-access.log
```

---

## 🧰 Maintenance Scripts

### Restart all stacks
`/usr/local/bin/restart-compose-stacks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE="/srv/docker"

find "$BASE" -maxdepth 3 -type f -name "docker-compose.yml" -print0 \
| while IFS= read -r -d '' f; do
  d="$(dirname "$f")"
  (cd "$d" && docker compose up -d --remove-orphans)
done

docker container prune -f
docker image prune -f
docker builder prune -f
```

---

### Cleanup logs & temp
`/usr/local/bin/cleanup-logs.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

KEEP="/var/log/secure-audit"
ARCH="$KEEP/archive"
mkdir -p "$ARCH"

ts="$(date +%F_%H%M%S)"

for f in "$KEEP"/redis-access.log; do
  if [[ -s "$f" ]]; then
    gzip -c "$f" > "$ARCH/$(basename "$f").$ts.gz"
    : > "$f"
  fi
done

journalctl --vacuum-size=200M
rm -rf /tmp/* /var/tmp/*
df -h /
```

---

## 🚀 Bring-Up Script

`/usr/local/bin/docker-stacks-up.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE="/srv/docker"
docker network create web || true
docker network create caddy_net || true

find "$BASE" -maxdepth 3 -name docker-compose.yml -print0 | while read -d '' f; do
  (cd "$(dirname "$f")" && docker compose up -d)
done
```

---

## 🕒 Cron Jobs (Not Enabled Yet)

```cron
0 4 * * 0 /usr/local/bin/cleanup-logs.sh
15 4 * * 0 /usr/local/bin/restart-compose-stacks.sh
```

---

## ▶️ Resume Plan

1. Bring up Caddy
2. Bring up Paperless
3. Bring up Immich
4. Bring up dev databases
5. Update Caddyfile
6. Validate ports
7. Enable cron jobs

---

## 🔁 Chat Handoff Block

```
I have a Hetzner VPS with Docker.
SSH is hardened, Docker is under /srv/docker,
Caddy is the only public entry,
Redis/Postgres are internal-only,
maintenance scripts exist,
stopped before enabling cron and bringing stacks up.
```
