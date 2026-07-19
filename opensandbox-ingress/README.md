# OpenSandbox ingress — server, gateway, and the `wildcard → header` rewrite

Simple notes on how sandbox traffic is routed, and why the Helm chart rewrites
the route mode for the gateway binary.

## The two pieces

**opensandbox-server**
- The control plane. It creates sandboxes and hands out their URLs.
- It does *not* proxy sandbox traffic itself. It just decides what each
  sandbox's public URL looks like, based on the route mode in its config.

**opensandbox-ingress-gateway**
- A reverse proxy. It is the single entry point for all sandbox traffic.
- Every request that comes in, it reads a routing token (`<sandbox-id>-<port>`),
  finds that sandbox's pod, and forwards the request to it.
- The gateway binary understands only **two** modes: `header` and `uri`.

## How a request flows

```
browser ──> nginx Ingress ──> opensandbox-ingress-gateway ──> sandbox pod
              (*.sandbox.systrox.com)      (reads <id>-<port>, proxies)
```

The apex host `sandbox.systrox.com` goes to the **server** (the API/control plane).
Everything under `*.sandbox.systrox.com` goes to the **gateway** (the sandboxes).
See [opensandbox-ingress.yaml](opensandbox-ingress.yaml).

## The three route modes

The route mode decides **where the routing token lives** in the request. The
server generates URLs to match, and the gateway parses them.

| Mode | URL the server hands out | Where the token is | Works in a browser? |
|------|--------------------------|--------------------|---------------------|
| `header` | `sandbox.systrox.com` + header `OPEN-SANDBOX-INGRESS: abc123-8080` | a custom HTTP header | **No** — a browser can't attach a custom header to every request |
| `uri` | `sandbox.systrox.com/abc123/8080/...` | the URL path | **No** — breaks a Next.js SPA's absolute asset paths (`/_next/static/...`) |
| `wildcard` | `abc123-8080.sandbox.systrox.com` | the subdomain (the `Host` header) | **Yes** — each sandbox is its own origin |

Our sandboxes serve a Next.js SPA in the browser, so we need `wildcard`. Only
wildcard gives each sandbox a real hostname the browser uses automatically on
every request (JS chunks, CSS, `fetch`, navigations, websockets).

## Why the gateway can still handle wildcard

The gateway has no `wildcard` mode — but its `header` mode already reads the
`Host` header as a fallback. From the gateway source
(`components/ingress/pkg/proxy/host.go`):

```go
func (p *Proxy) parseTargetHostByHeader(r *http.Request) string {
    targetHost := r.Header.Get(SandboxIngress)   // custom header first
    if targetHost != "" { return targetHost }
    ...
    return r.Host                                 // <-- falls back to the Host header
}
```

A wildcard URL puts `abc123-8080` in the subdomain, which arrives as the `Host`
header. So `header` mode reads it correctly. `wildcard` and `header` carry the
**same token** (`<id>-<port>`) — only the location differs (Host vs custom header).

## Why we rewrite the value in `ingress-gateway.yaml`

One Helm value — `server.gateway.gatewayRouteMode` — feeds **two** consumers:

1. The **server** config (`gateway.route.mode` in `config.toml`) — needs `wildcard`
   so it generates browser-friendly per-subdomain URLs.
2. The **gateway binary** `--mode` flag — only accepts `header` / `uri`. Passing
   `wildcard` fails: the binary hits its `default:` branch and returns
   `unknown ingress mode: wildcard` (host.go:48-49), and every request 400s.

Since there is only **one** value for both, the chart translates it at the
gateway's CLI flag only:

```gotemplate
# templates/ingress-gateway.yaml
- "--mode={{ if eq .Values.server.gateway.gatewayRouteMode "wildcard" }}header{{ else }}{{ .Values.server.gateway.gatewayRouteMode }}{{ end }}"
```

Result:
- server → `gateway.route.mode = "wildcard"` (good URLs) ✅
- gateway → `--mode=header` (a flag the binary accepts, reads `Host`) ✅

The server keeps doing the wildcard thing; only the label handed to the binary
is changed to one it understands. We rewrite instead of adding a second value so
the operator sets a single mode and can't create a broken split (e.g. server
`wildcard` + gateway `uri`).

## Key source references

- Server URL generation per mode — `server/opensandbox_server/services/helpers.py:213-232`
- Gateway accepted modes (`header`, `uri` only) — `components/ingress/pkg/proxy/host.go:27-30`
- Header mode falls back to `Host` — `components/ingress/pkg/proxy/host.go:93-104`
- Unknown mode → 400 — `components/ingress/pkg/proxy/host.go:48-49`
- The rewrite — `kubernetes/charts/opensandbox-server/templates/ingress-gateway.yaml`
- Same value feeds server config — `kubernetes/charts/opensandbox-server/templates/_helpers.tpl:118`
