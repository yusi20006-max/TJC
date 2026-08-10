# TJC Provider Architecture

TJC v2 isolates external AI/development services behind a provider boundary. The default provider is `jules`.

## Architecture

```text
TJC command / workflow
        |
        v
  Provider Interface
        |
        v
  Jules Adapter
        |
        v
 Jules REST API
```

The provider boundary prevents commands, workflows, Jobs, and future MCP tools from depending directly on provider-specific HTTP details.

## Configuration

Select the provider with:

```sh
export TJC_PROVIDER=jules
```

The default is `jules`.

The Jules API key is supplied through:

```sh
export JULES_API_KEY='...'
```

Do not commit keys to configuration files, workflow definitions, Job records, or logs.

## Jules Adapter

The Jules adapter is implemented in `providers/jules.sh` and uses:

`https://jules.googleapis.com/v1alpha`

Authentication is sent only as the `X-Goog-Api-Key` request header.

The adapter provides the provider-facing operations:

- authentication check
- source listing
- session creation
- session retrieval
- activity listing
- pull-request operation boundary
- operation cancellation

Network failures and 5xx responses are retried with a bounded three-attempt policy. Authentication and client errors are not retried.

## Provider Loader

`lib/provider.sh` loads exactly one provider implementation and exposes provider-neutral initialization.

Future providers should be added without changing callers:

```text
providers/
  base.sh
  jules.sh
  future-provider.sh
```

## Security Rules

1. Never print `JULES_API_KEY`.
2. Never include authentication headers in debug output.
3. Never store provider credentials in Jobs or workflow reports.
4. Validate provider identifiers before loading implementation files.
5. Keep provider-specific URLs inside provider adapters.
6. Do not add arbitrary command execution to provider adapters.

## Testing

Provider tests should verify:

- provider selection
- missing credentials
- successful authentication
- successful source/session requests
- authentication failures
- non-retryable client failures
- bounded retry behavior
- absence of credentials in output

## Adding a Provider

A future provider must implement the capabilities required by the provider interface and must be independently testable. It must not modify the Job or Workflow domain models merely to fit provider-specific behavior.
