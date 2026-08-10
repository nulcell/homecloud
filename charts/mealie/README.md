# mealie

Mealie - a self-hosted recipe manager, meal planner and shopping list.

Follows the upstream PostgreSQL deployment guide
(<https://docs.mealie.io/documentation/getting-started/installation/postgres/>),
adapted for Kubernetes: the compose file's sidecar `postgres` service is
replaced by a CNPG `Cluster` owned by the app directory, and the compose
`environment:` block maps onto the `database` / `mealie` values.

`values.yaml` models the settings from
<https://docs.mealie.io/documentation/getting-started/installation/backend-config/>
that are worth having as first-class knobs - general, security, database, OIDC
and SMTP. Everything else (`LDAP_*`, `THEME_*`, `SCRAPER_*`, `OPENAI_*`) goes
through `mealie.extraEnv`.

## OIDC

`mealie.baseUrl` must be the public hostname before OIDC works - Mealie builds
its callback URL from it. The provider needs both
`<baseUrl>/login` and `<baseUrl>/login?direct=1` as strict redirect URIs.

For authentik specifically, group membership arrives as application
entitlements rather than the default `groups` claim, so set
`mealie.oidc.groupsClaim: entitlements` and add the "Application Entitlements"
scope mapping to the provider. See
<https://integrations.goauthentik.io/documentation/mealie/>.

## Network policy

`networkPolicy` (enabled by default) restricts ingress to the Gateway,
cloudflared (when it fronts the pod directly) and `allowedNamespaces`, all on
the web port. Egress defaults to open (`egress.allowAll`) because recipe
scraping fetches arbitrary URLs, with an explicit always-on rule to the
Postgres pods so tightening egress later can't cut the app off from its
database. The CNPG cluster itself gets its own policy where it is deployed
(see the gitops overlay). It renders a CiliumNetworkPolicy rather than a
networking.k8s.io NetworkPolicy because Cilium's Gateway API forwards traffic
with the reserved `ingress` identity, which a plain NetworkPolicy cannot
select.
