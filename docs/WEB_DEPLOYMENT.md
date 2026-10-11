# Cloudflare Workers Web Deployment

This project can be deployed to Cloudflare Workers as static assets after a Flutter Web build.

## Build-time APK link

The web-only APK download CTA reads this build-time variable:

```bash
--dart-define=OMNITUNE_WEB_APK_URL=https://example.com/omnitune.apk
```

If the variable is missing or invalid, the banner still renders on Web, but the download button is disabled.

## WebDAV reverse proxy

Web builds now default to using a reverse proxy path for WebDAV requests:

```bash
/api/webdav/
```

You can override it at build time when needed:

```bash
--dart-define=OMNITUNE_WEB_WEBDAV_PROXY_BASE_URL=https://example.com/api/webdav/
```

When deployed on Cloudflare Workers with the included Worker script, `/api/webdav/*` is handled server-side and proxied to the user-configured WebDAV origin. This avoids direct browser-to-WebDAV CORS failures.

## Local Web validation

Debug Web server:

```bash
OMNITUNE_WEB_APK_URL=https://example.com/omnitune.apk \
OMNITUNE_WEB_WEBDAV_PROXY_BASE_URL=http://127.0.0.1:8788/api/webdav/ \
./scripts/run_web_server.sh
```

Release-style static build:

```bash
OMNITUNE_WEB_APK_URL=https://example.com/omnitune.apk ./scripts/build_web.sh
```

Local WebDAV proxy for `web-server` debugging:

```bash
./scripts/run_webdav_proxy.sh
```

Static file server with SPA fallback after the build finishes:

```bash
./scripts/serve_web.sh --directory build/web --port 8080
```

## Deploy to Workers

The repository includes a `wrangler.jsonc` configured for Flutter's `build/web` output, SPA fallback, and a Worker script for `/api/webdav/*`:

```jsonc
{
  "main": "worker/index.js",
  "assets": {
    "directory": "./build/web",
    "binding": "ASSETS",
    "not_found_handling": "single-page-application",
    "run_worker_first": ["/api/*"]
  }
}
```

Deploy with Wrangler after the Flutter build finishes:

```bash
npx wrangler deploy
```

## Important Web limits

- Web keeps `WebDAV` and `CloudDrive`.
- Web removes `FTP`, `SFTP`, and `Samba` from UI and runtime flows.
- The WebDAV proxy avoids direct browser CORS failures, but the upstream server still needs to accept the proxied HTTP methods and authentication.
- The current proxy forwards credentials as Basic auth to the upstream WebDAV server. If your server requires another scheme, the proxy will need another pass.
- Remote playback and metadata requests still depend on the upstream server handling HTTPS and byte-range requests correctly.
