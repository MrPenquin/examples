# LLM Gateway Proxy

A minimal [Cloudflare Worker](https://developers.cloudflare.com/workers/) that validates
an inbound [Microsoft Entra](https://learn.microsoft.com/entra/) JWT, then proxies the
request to [Cloudflare AI Gateway](https://developers.cloudflare.com/ai-gateway/) with the
gateway auth token attached and the caller's validated identity passed as metadata.

**Full walkthrough:** https://ryanj.io/writing/claude-3p-mode/

## Deploy

[![Deploy to Cloudflare](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/MrPenquin/examples/tree/main/claude-3p/llm-gateway-proxy)

The repo must be **public** on GitHub/GitLab. Deploying prompts you for:

| Name | Type | Description |
|---|---|---|
| `CLOUDFLARE_ACCOUNT_ID` | var | Your Cloudflare account ID; used to build the AI Gateway request path. |
| `GATEWAY_NAME` | var | The name of your AI Gateway. Defaults to `main`. |
| `CF_AIG_TOKEN` | secret | AI Gateway authentication token (Gateway → Settings → Authenticated Gateway). |
| `ENTRA_TENANT_ID` | secret | Entra tenant ID (UUID); inbound tokens must be issued by this tenant. |
| `ENTRA_CLIENT_ID` | secret | Entra App Registration client ID (UUID); the expected `aud` claim. |

The Worker deploys to a free `<name>.workers.dev` subdomain. To use a custom domain,
uncomment the `[[routes]]` block in `wrangler.toml` and redeploy. See the blog post for
local development, manual deploy, and testing.
