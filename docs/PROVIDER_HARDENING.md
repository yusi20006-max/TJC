# Jules Provider Hardening

The Jules provider is the only module that owns Jules-specific HTTP transport and authentication.

## Safety Properties

- Jules endpoints must use HTTPS.
- HTTP methods are explicitly allow-listed.
- Endpoint strings are restricted to API path characters.
- Connection and total request timeouts are bounded.
- Retry count is bounded by `TJC_JULES_MAX_ATTEMPTS`.
- Retryable failures include network failures, rate limiting, request timeout, and transient 5xx responses.
- Authentication failures are not retried.
- Response bodies are not emitted on errors, preventing accidental credential leakage through provider diagnostics.
- Backoff is capped by `TJC_JULES_BACKOFF_CAP`.

## Configuration

```sh
export JULES_API_KEY='...'
export JULES_BASE_URL='https://jules.googleapis.com/v1alpha'
export TJC_JULES_MAX_ATTEMPTS=3
export TJC_JULES_CONNECT_TIMEOUT=10
export TJC_JULES_MAX_TIME=30
export TJC_JULES_BACKOFF_CAP=8
```

Invalid numeric settings and non-HTTPS base URLs are rejected before network execution.

## Boundary

Jobs, Workflows, Queue, Scheduler, MCP, and Policy must call provider functions instead of constructing Jules-specific curl commands themselves.
