# cluckcrossing.site Worker — deploy & recovery

## What broke (2026-11-18)
The `cluckcrossing-site` Worker was redeployed at **13:40** (and again **17:52**) as a
minimal stub:
```js
export default { fetch(request, env) { return env.ASSETS.fetch(request); } };
```
That stub only serves the static site, so `/check` and `/health` returned 404 and the
two secrets (`CHECK_API_KEY`, `BANDA_CLICK_TOKEN`) were dropped. Banda click logs confirm
the API worked only in the window the full worker was live (10:37–13:35 that day).

Fix = redeploy the full `worker.mjs` (this folder) **with the two secrets restored**, and
always deploy site + API together via this config so a site-only deploy can't wipe the API.

## Required secrets (Worker)
| Secret | Purpose | Source |
|---|---|---|
| `CHECK_API_KEY` | auth header `X-Check-API-Key` the Supabase `resolve-player` function sends to `/check` | must **equal** the Supabase function secret `CHECK_API_KEY` |
| `BANDA_CLICK_TOKEN` | header `X-Click-Token` the worker sends to the Banda click API | Banda dashboard / Jira |

`CHECK_API_KEY` cannot be read back from Supabase (the Management API returns only a
hash). Two options:
- **Reuse** the existing value if you have it, or
- **Rotate**: pick a new random value and set it on BOTH the Worker secret and the
  Supabase function secret `CHECK_API_KEY` so they match.

## Option A — wrangler (needs Node on the deploy machine)
```bash
cd Site && ./configure.sh cluckcrossing.site OleksiyHrytsai943@icloud.com && cd ..
cd Backend/Cloudflare
wrangler deploy
wrangler secret put CHECK_API_KEY
wrangler secret put BANDA_CLICK_TOKEN
```

## Option B — Cloudflare REST API (no Node)
Account `ad8e00b0329b2049520603ea0396c707`, zone `cluckcrossing.site`, worker
`cluckcrossing-site`. Uses the global API key (header `X-Auth-Email` + `X-Auth-Key`).
Steps: open an assets-upload-session, upload the configured `Site/` files, then
`PUT .../workers/scripts/cluckcrossing-site` with `worker.mjs`, the `ASSETS` binding,
`run_worker_first`, and the two `secret_text` bindings. Keep the existing custom domain.

## Verify
```bash
curl https://cluckcrossing.site/health           # -> {"status":"ok"}
curl -X POST https://cluckcrossing.site/check     # -> 401 {"error":"unauthorized"} (alive)
```
`not_configured` / `check_not_configured` / `upstream_not_configured` = a secret is missing.
