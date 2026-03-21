# VPS Hardening Checklist

This is the shortest path to getting this copied Docker stack into a safer shape on a new VPS.

## 1. Rotate exposed credentials first

These files currently contain live-looking secrets and should be treated as compromised until rotated:

- `dashy/.env`
- `immich-app/.env`
- `dev-dbs/.env`
- `paperless-ngx/docker-compose.env`
- `stirling-pdf/.env`
- `mongo-db/docker-compose.yml`

Suggested order:

1. Rotate app admin passwords.
2. Rotate database passwords.
3. Regenerate API keys and tokens.
4. Update the files on the VPS.
5. Restart only the affected stacks.

## 2. Recreate required external Docker networks

Several compose projects depend on external networks and will fail on a fresh host if they do not exist.

```bash
docker network create web || true
docker network create caddy_net || true
```

## 3. Keep Caddy as the only public entry point

The highest-risk direct port bindings have been moved to `127.0.0.1`, but you should still review every stack before exposing anything publicly.

Current public-entry intent:

- `caddy` should own `80` and `443`
- internal apps should join `caddy_net`
- databases and admin UIs should stay localhost-only, VPN-only, or private-network-only

## 4. Pin image versions before routine updates

Several services still use `:latest`. Before your next broad `docker compose pull`, pin versions so updates are deliberate and reversible.

Priority stacks to pin:

- `dashy`
- `uptime-kuma`
- `portainer`
- `paperless-ngx`
- `freshrss`
- `netdata`
- `portracker`

## 5. Check host firewall

Make sure the VPS firewall only permits what you expect:

- allow `22/tcp`
- allow `80/tcp`
- allow `443/tcp`
- deny direct database/admin ports unless intentionally needed

## 6. Verify bind-mount ownership

After copying data to a new VPS, confirm container users can still read and write the bind mounts under `/srv/docker/data`.

Focus on:

- `immich`
- `paperless-ngx`
- `dev-postgres`
- `portainer`
- `uptime-kuma`

## 7. Review tracked secret files in git

`.gitignore` already excludes `*.env`, but tracked files stay tracked. If this repository ever leaves a private machine:

1. Move secrets into untracked env files or a secret manager.
2. Replace committed secrets with templates.
3. Rotate any value that was previously committed.

## 8. Smoke test after changes

Run these after each stack is brought up:

```bash
docker compose ps
docker compose logs --tail=100
docker ps --format 'table {{.Names}}\t{{.Ports}}'
ss -tulpn
```
