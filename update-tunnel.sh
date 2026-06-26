#!/bin/bash
# update-tunnel.sh <tunnel-url>
# Updates the proxytest solution to use the given tunnel URL

set -e

TUNNEL_URL="${1:?Usage: $0 <tunnel-url>}"
BASE=https://container-hosting.runtime.kyma.dev.sap
KEY="${CONTAINER_HOSTING_KEY:?Set CONTAINER_HOSTING_KEY env var}"

# Strip trailing slash
TUNNEL_URL="${TUNNEL_URL%/}"
TUNNEL_HOST=$(echo "$TUNNEL_URL" | sed 's|https://||' | sed 's|http://||')

echo "Updating proxytest solution: upstream=$TUNNEL_URL host=$TUNNEL_HOST"

cat > /tmp/solution-update.json << EOF
{
  "spec": {
    "solutionName": "proxytest",
    "tenant": "test",
    "version": "1.0.0",
    "regions": [{"provider": "aws", "geography": "eu"}],
    "assets": [
      {
        "id": "agent",
        "kind": "agent",
        "port": 7681,
        "image": "ghcr.io/pbochynski/claude-sandbox:latest",
        "resources": {
          "requests": {"cpu": "200m", "memory": "256Mi"},
          "limits": {"cpu": "1000m", "memory": "512Mi"}
        },
        "sandboxing": {
          "tenantClaim": "sub",
          "idleTTL": "60m",
          "runtimeClassName": "gvisor",
          "command": "ttyd -p 7681 -W bash",
          "providers": [
            {
              "name": "haiproxy",
              "port": 3129,
              "upstream": "${TUNNEL_URL}",
              "secretRef": {
                "name": "haiproxy-key",
                "key": "HAIPROXY_API_KEY"
              },
              "injectEnv": [
                {"name": "ANTHROPIC_API_KEY", "placeholder": "placeholder:haiproxy"},
                {"name": "ANTHROPIC_BASE_URL", "value": "http://localhost:3129/anthropic"}
              ]
            }
          ]
        }
      }
    ],
    "network": {
      "egress": {
        "allowedHosts": ["${TUNNEL_HOST}"]
      }
    }
  }
}
EOF

curl -s -X PUT \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  "$BASE/projects/5f4ba0671e45/solutions/proxytest" \
  -d @/tmp/solution-update.json | python3 -c "
import sys, json
r = json.load(sys.stdin)
print('Status:', r.get('status', 'unknown'))
print('Solution ID:', r.get('id', ''))
"

echo "Done. Wait ~30s for reconcile, then open:"
echo "https://agent-e62f9253ee07.runtime.kyma.dev.sap"
