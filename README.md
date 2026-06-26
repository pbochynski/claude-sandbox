# claude-sandbox demo

Web terminal with Claude Code, connected to your local hai-proxy via a public tunnel.

## Architecture

```
sandbox pod (container-hosting)
  agent container (claude-sandbox image)
    ANTHROPIC_API_KEY=placeholder:haiproxy
    ANTHROPIC_BASE_URL=http://localhost:3129/anthropic
         │ plain HTTP
         ▼
  provider-proxy sidecar (localhost:3129)
    rewrites placeholder → real hai-proxy API key
    upstream = https://<your-tunnel-url>
         │ HTTPS via connect-proxy (localhost:3128)
         ▼
public tunnel URL (localhost.run / ngrok / chisel)
         ↑ SSH / WebSocket from your laptop
hai-proxy on localhost:6655
    API key: <yours>
         ↓
api.hyperspace.tools.sap / Anthropic
```

## Step 1: Start your tunnel

Pick one:

```bash
# Option A: localhost.run (no install needed, uses SSH)
ssh -R 80:localhost:6655 nokey@localhost.run
# → gives you a URL like https://abc123.lhr.life

# Option B: chisel (Go binary, less likely to be blocked by antivirus)
chisel client https://<chisel-server-url> R:8080:localhost:6655

# Option C: ngrok
ngrok http 6655
```

## Step 2: Update the solution with your tunnel URL

```bash
./update-tunnel.sh https://YOUR_TUNNEL_URL
```

## Step 3: Create the hai-proxy API key secret

```bash
kubectl --kubeconfig <worker-kubeconfig> create secret generic haiproxy-key \
  --from-literal=HAIPROXY_API_KEY=<your-hai-proxy-api-key> \
  -n s-e62f9253ee07
```

## Step 4: Open the web terminal

The agent URL is: `https://agent-e62f9253ee07.runtime.kyma.dev.sap`

Open it in your browser with a JWT token:
```
https://agent-e62f9253ee07.runtime.kyma.dev.sap/?token=<your-jwt>
```

## Step 5: Run Claude in the terminal

```bash
# Inside the web terminal:
claude
```

Claude will use ANTHROPIC_BASE_URL=http://localhost:3129/anthropic, which routes through
the provider-proxy sidecar → tunnel → your hai-proxy → Anthropic.

The ANTHROPIC_API_KEY in the sandbox contains only `placeholder:haiproxy` — the real key
is never visible to the agent process.
