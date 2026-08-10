# TJC v2.1 Provider Hardening

The Jules provider is the external API boundary. It must remain isolated from Jobs, Workflows, Queue, and MCP domains.

## Reliability Contract

- connection timeout and total request timeout are bounded
- transient transport and 5xx failures may be retried with bounded backoff
- 4xx authentication and validation failures are not retried
- credentials are supplied only through `X-Goog-Api-Key`
- credentials are never emitted in errors or logs
- successful response bodies are passed through without exposing request headers
- non-success responses are classified into stable local error classes

## Session Lifecycle

Session creation, lookup, activity listing, pull-request lookup, and cancellation are independent provider operations. Higher-level polling belongs in the session/Job domain and must not be hidden inside the HTTP primitive.

## Termux Compatibility

The adapter uses POSIX shell plus `curl`, `mktemp`, and standard utilities available on Termux/Linux. No root daemon or platform-specific service is required.
