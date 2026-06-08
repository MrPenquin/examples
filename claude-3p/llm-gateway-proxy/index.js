const GATEWAY_BASE = "https://gateway.ai.cloudflare.com";

const b64urlDecode = (s) => atob(s.replace(/-/g, "+").replace(/_/g, "/"));

async function getJwks(tenantId) {
  const url = `https://login.microsoftonline.com/${tenantId}/discovery/v2.0/keys`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`JWKS fetch failed: ${res.status}`);
  return res.json();
}

async function validateJwt(token, tenantId, clientId) {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("Malformed JWT");

  const [headerB64, payloadB64, sigB64] = parts;
  const header = JSON.parse(b64urlDecode(headerB64));
  const payload = JSON.parse(b64urlDecode(payloadB64));

  // Check expiry
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < now) throw new Error("Token expired");

  // Check issuer — Entra v2 tokens use /v2.0 suffix
  const expectedIssuer = `https://login.microsoftonline.com/${tenantId}/v2.0`;
  if (payload.iss !== expectedIssuer) {
    throw new Error(`Unexpected issuer: ${payload.iss}`);
  }

  // Check audience
  const aud = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!aud.includes(clientId)) {
    throw new Error(`Unexpected audience: ${payload.aud}`);
  }

  // Find matching key by kid and verify the signature
  const jwks = await getJwks(tenantId);
  const jwk = jwks.keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new Error(`No matching key for kid: ${header.kid}`);

  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature = Uint8Array.from(b64urlDecode(sigB64), (c) =>
    c.charCodeAt(0),
  );

  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    signature,
    signingInput,
  );
  if (!valid) throw new Error("JWT signature invalid");

  return payload;
}

export default {
  async fetch(request, env) {
    const tenantId = env.ENTRA_TENANT_ID;
    const clientId = env.ENTRA_CLIENT_ID;
    const accountId = env.CLOUDFLARE_ACCOUNT_ID;
    const gatewayName = env.GATEWAY_NAME;

    if (!tenantId || !clientId || !accountId || !gatewayName) {
      return new Response("Gateway misconfigured", { status: 500 });
    }

    // Validate inbound JWT
    const authHeader = request.headers.get("authorization") ?? "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!token) {
      return new Response("Unauthorized", { status: 401 });
    }

    let claims;
    try {
      claims = await validateJwt(token, tenantId, clientId);
    } catch {
      return new Response("Unauthorized", { status: 401 });
    }

    // Build the gateway URL
    const url = new URL(request.url);
    const target = new URL(
      `/v1/${accountId}/${gatewayName}${url.pathname}${url.search}`,
      GATEWAY_BASE,
    );

    const headers = new Headers(request.headers);

    // Swap inbound Bearer for the gateway token
    headers.delete("authorization");
    if (env.CF_AIG_TOKEN) {
      headers.set("cf-aig-authorization", `Bearer ${env.CF_AIG_TOKEN}`);
    }

    // Forward validated identity as gateway metadata
    headers.set(
      "cf-aig-metadata",
      JSON.stringify({
        userId: claims.oid,
        userEmail: claims.preferred_username ?? claims.email ?? claims.upn,
        userName: claims.name,
      }),
    );

    const response = await fetch(target, {
      method: request.method,
      headers,
      body: request.body,
    });

    return new Response(response.body, {
      status: response.status,
      headers: response.headers,
    });
  },
};
