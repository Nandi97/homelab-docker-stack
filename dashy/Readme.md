# Dashy – KIGTech VPS Dashboard

Dashy is the main web dashboard for the KIGTech VPS, providing quick access to
self-hosted services, monitoring, and system information.

This setup uses **environment-based templating** to keep API keys and secrets
out of version control.

---

## Architecture

- **Dashy container** serves the UI
- **dashy-render sidecar** generates `conf.yml` from `conf.yml.template`
- Secrets are stored in `.env`
- Final config is generated at runtime using `envsubst`

```text
.env ─┐
      ├─> envsubst ──> conf.yml (generated)
conf.yml.template ─┘

| File                 | Purpose                             |
| -------------------- | ----------------------------------- |
| `docker-compose.yml` | Dashy + renderer services           |
| `.env`               | Secrets (API keys, usernames, etc.) |
| `conf.yml.template`  | Dashboard layout (safe for git)     |
| `conf.yml`           | Generated config (DO NOT EDIT)      |

Files

First-Time Setup

Create .env (do not commit this file)

Ensure conf.yml.template exists

Start Dashy:

docker compose up -d

Access:

https://dash.kigtech.digital
Updating Configuration

Edit layout/widgets → conf.yml.template

Edit secrets/keys → .env

Apply changes:

docker compose up -d --force-recreate

⚠️ conf.yml is auto-generated and will be overwritten on restart.

Updating Dashy
docker compose pull
docker compose up -d
Troubleshooting
Dashy not starting
docker logs dashy
docker logs dashy-render
Regenerate config manually
docker compose up -d --force-recreate
Security Notes

.env permissions should be 600

API keys should be read-only where possible

conf.yml must never be committed


---

## `.gitignore` (add these lines)

```gitignore
# Dashy generated config & secrets
/srv/docker/dashy/conf.yml
/srv/docker/dashy/.env

# Optional: Dashy runtime data
/srv/docker/data/dashy/

If your repo root is already /srv/docker, a safer relative version:

dashy/conf.yml
dashy/.env
data/dashy/