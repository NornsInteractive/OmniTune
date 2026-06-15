const WEBDAV_PROXY_PREFIX = "/api/webdav";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname.startsWith(WEBDAV_PROXY_PREFIX)) {
      return handleWebDavProxy(request, url);
    }

    return env.ASSETS.fetch(request);
  },
};

async function handleWebDavProxy(request, url) {
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(request),
    });
  }

  const targetUrlHeader = request.headers.get("x-omnitune-target-url");
  if (targetUrlHeader) {
    let targetUri;
    try {
      targetUri = new URL(targetUrlHeader);
    } catch {
      return jsonError(request, 400, "Invalid target WebDAV request URL.");
    }

    return forwardRequest(request, targetUri);
  }

  const targetBaseUrl = request.headers.get("x-omnitune-target-base-url");
  if (!targetBaseUrl) {
    return jsonError(request, 400, "Missing x-omnitune-target-base-url header.");
  }

  let targetBaseUri;
  try {
    targetBaseUri = new URL(targetBaseUrl);
  } catch {
    return jsonError(request, 400, "Invalid target WebDAV base URL.");
  }

  const targetPath = url.pathname.slice(WEBDAV_PROXY_PREFIX.length);
  const normalizedTargetPath = targetPath.startsWith("/")
    ? targetPath.slice(1)
    : targetPath;
  const targetUrl = new URL(normalizedTargetPath, ensureTrailingSlash(targetBaseUri));

  return forwardRequest(request, targetUrl);
}

async function forwardRequest(request, targetUrl) {
  const upstreamHeaders = new Headers();
  copyForwardHeaders(request.headers, upstreamHeaders);

  const username = request.headers.get("x-omnitune-username") ?? "";
  const password = request.headers.get("x-omnitune-password") ?? "";
  if (username || password) {
    upstreamHeaders.set(
      "authorization",
      `Basic ${btoa(`${username}:${password}`)}`,
    );
  }

  const init = {
    method: request.method,
    headers: upstreamHeaders,
    body: canHaveBody(request.method) ? request.body : undefined,
    redirect: "follow",
  };

  const upstreamResponse = await fetch(targetUrl, init);
  const responseHeaders = new Headers(upstreamResponse.headers);
  mergeCorsHeaders(responseHeaders, request);

  return new Response(upstreamResponse.body, {
    status: upstreamResponse.status,
    statusText: upstreamResponse.statusText,
    headers: responseHeaders,
  });
}

function ensureTrailingSlash(url) {
  if (url.pathname.endsWith("/")) {
    return url;
  }
  return new URL(`${url.pathname}/`, url);
}

function canHaveBody(method) {
  return method !== "GET" && method !== "HEAD";
}

function copyForwardHeaders(source, target) {
  for (const [name, value] of source.entries()) {
    const lower = name.toLowerCase();
    if (
      lower === "host" ||
      lower === "origin" ||
      lower === "referer" ||
      lower === "connection" ||
      lower === "content-length" ||
      lower.startsWith("x-omnitune-")
    ) {
      continue;
    }
    target.set(name, value);
  }
}

function corsHeaders(request) {
  const origin = request.headers.get("origin") ?? "*";
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET,HEAD,OPTIONS,PROPFIND",
    "access-control-allow-headers":
      "Authorization,Content-Type,Depth,Range,Accept,Accept-Charset,X-OmniTune-Target-Base-Url,X-OmniTune-Username,X-OmniTune-Password",
    "access-control-expose-headers":
      "Content-Length,Content-Range,Content-Type,DAV,ETag,Last-Modified",
    "access-control-allow-credentials": "false",
    vary: "Origin",
  };
}

function mergeCorsHeaders(headers, request) {
  const cors = corsHeaders(request);
  for (const [name, value] of Object.entries(cors)) {
    headers.set(name, value);
  }
}

function jsonError(request, status, message) {
  const headers = new Headers({
    "content-type": "application/json; charset=utf-8",
  });
  mergeCorsHeaders(headers, request);

  return new Response(JSON.stringify({ error: message }), {
    status,
    headers,
  });
}
