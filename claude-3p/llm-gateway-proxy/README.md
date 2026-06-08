# LLM Gateway Proxy

A minimal [Cloudflare Worker](https://developers.cloudflare.com/workers/) that validates
an inbound [Microsoft Entra](https://learn.microsoft.com/entra/) JWT, then proxies the
request to [Cloudflare AI Gateway](https://developers.cloudflare.com/ai-gateway/) with the
gateway auth token attached and the caller's validated identity passed as metadata.

**Full walkthrough:** https://ryanj.io/writing/claude-3p-mode/

## One-Click Deploy

[![Deploy to Cloudflare](https://deploy.workers.cloudflare.com/button)](https://deploy.workers.cloudflare.com/?url=https://github.com/MrPenquin/examples/tree/main/claude-3p/llm-gateway-proxy)

## Deploy from a clone

Prefer to deploy from the command line? Clone the repo and use
[Wrangler](https://developers.cloudflare.com/workers/wrangler/) directly:

```bash
git clone https://github.com/MrPenquin/examples.git
cd examples/claude-3p/llm-gateway-proxy
npm install

# Set CLOUDFLARE_ACCOUNT_ID and GATEWAY_NAME in wrangler.toml ([vars]),
# then provide the three secrets:
npx wrangler secret put CF_AIG_TOKEN
npx wrangler secret put ENTRA_TENANT_ID
npx wrangler secret put ENTRA_CLIENT_ID

npx wrangler deploy
```

For local testing, run `npx wrangler dev` after copying `.dev.vars.example` to
`.dev.vars` and filling in the secret values.
