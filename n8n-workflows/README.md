# n8n AI Assistant: Code Sandbox + Free Web Search

All free. Nothing here costs anything.

## 1. Code sandbox (already enabled on the A1)

`N8N_RUNNERS_ENABLED=true` + `N8N_RUNNERS_MODE=internal` is set in
`/opt/n8n/docker-compose.yaml` (and in `scripts/bootstrap-oracle.sh` for rebuilds).
Max 5 concurrent runners — right-sized for 2 OCPUs.

What this gives you in the **Code node**:
- **JavaScript**: runs sandboxed out of the box. No setup.
- **Python (Pyodide)**: select Python in the Code node language picker.
  First run downloads the runtime (~10s, needs egress — fine). No extra
  containers, no keys.

Verify: new workflow → Manual Trigger → Code node (Python:
`return [{"ok": True}]`) → Execute. If it returns, sandbox works.

Limits: internal runners share the n8n process memory. Keep heavy
numpy/pandas jobs small, or move them to a scheduled workflow at night.

## 2. Free web search for the AI Agent

| Provider | Free tier | Key | Notes |
|---|---|---|---|
| **Brave Search API** (recommended) | 2,000 queries/mo, no card | brave.com/search/api | Fast, clean JSON |
| Tavily | 1,000 credits/mo | tavily.com | Built for AI/RAG, includes extracts |
| DuckDuckGo Instant Answer | free, no key | — | Thin results, good fallback |

### Brave setup (5 min)

1. Sign up at `brave.com/search/api` → copy API key.
2. n8n → Credentials → **Generic Auth** → name `Brave API key`:
   - Auth type: Header Auth
   - Name: `X-Subscription-Token`, Value: your key.
3. Import `ai-assistant-web-search.json` (n8n → Workflows → Import from file).
4. In the **Brave Web Search** node, attach your `Brave API key` credential.
5. Activate. POST `{"query": "..."}` to the webhook URL.

### Using it as an Agent tool

In an **AI Agent** node, add a **Custom Tool** workflow that calls this
webhook (or inline an HTTP Request tool with the Brave endpoint above).
Feed `search_context` into the agent prompt as ground truth — this is the
whole RAG loop for client demos, and it runs entirely on free tiers.

### Free LLM to pair with it

- **Ollama on the A1** (3B–8B fits in 12GB): `docker run -d --name ollama -p 11434:11434 -v ollama:/root/.ollama ollama/ollama`,
  then n8n **Ollama** credentials → host `http://host.docker.internal:11434`
  (add `extra_hosts: ["host.docker.internal:host-gateway"]` to n8n service).
- Or Gemini API free tier (AI Studio key) via the **Google Gemini** node.
