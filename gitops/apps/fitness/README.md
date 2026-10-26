# fitness

Running: `opengym` (`gym.nulcell.com`).

## Planned: SparkyFitness

Parked. Target `health.nulcell.com`: private first, public via cloudflared (no HTTPRoute, like `mealie`) once Authentik OIDC is set up.

- **Release**: second app-template release `sparkyfitness` (`values-sparkyfitness.yaml`).
- **Pod**: `docker.io/codewithcj/sparkyfitness_server` (3010, uid 1000) plus `sparkyfitness_frontend_nonroot` (8080, uid 101) as a sidecar. Pin tags.
- **Data**: CNPG Postgres 2Gi with barman (`postgres-backup.yaml`, 03:00; 02:00-02:45 are taken). Longhorn RWO volume for uploads/backup with the `backup` labels.
- **Auth**: Authentik OIDC only, signup off.
- **Secrets**: `api-encryption-key`, `better-auth-secret`, `app-db-password`, `oidc-client-secret` via ExternalSecret from 1Password.
- **Gotchas**: the server creates a second DB user (`sparky_app`), so the DB owner needs `CREATEROLE` (CNPG `postInitApplicationSQL`, or pre-create it with `managed.roles`). Verify `SPARKY_FITNESS_*` env names against upstream `.env.example`.
- **Also touch**: cloudflared `ingress` + `register-health` init container, and the `sparkyfitness-postgres` entry in `cluster/docs/backup-restore.md`.
- **Refs**: [compose](https://github.com/CodeWithCJ/SparkyFitness/blob/main/docker/docker-compose.prod.yml), [community Helm chart](https://github.com/CodeWithCJ/SparkyFitness/blob/main/helm/README.md).
