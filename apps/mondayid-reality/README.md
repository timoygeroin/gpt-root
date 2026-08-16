# MONDAYID REALITY v0.3.1

ChatGPT-native MCP App prototype. It is deliberately **SIMULATED** and is not a replacement for official emergency alerts.

## Production

- MCP: `https://mondayid-reality.vercel.app/mcp`
- Health: `https://mondayid-reality.vercel.app/health`
- Architecture: stateless signed state, serverless-safe
- Live safety adapters: `0`

## Tools

- `get_reality_state` — data only
- `render_reality` — renders the in-chat app
- `transition_demo` — retry-safe simulated state transition

## Safety gate

Do not claim live safety coverage until a real authoritative adapter has health, provenance, freshness, failure handling, and independent verification. Missing data is never evidence of safety.
