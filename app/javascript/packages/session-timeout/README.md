# `@18f/identity-session-timeout`

Utilities for managing a user's session.

## Usage

### `requestSessionStatus`

Request the current session status.

```ts
import { requestSessionStatus } from '@18f/identity-session-timeout';

const { live, timeout } = await requestSessionStatus();
```

### `requestSessionKeepAlive`

Request that the current session be kept alive.

```ts
import { requestSessionKeepAlive } from '@18f/identity-session-timeout';

const { live, timeout } = await requestSessionKeepAlive();
```
