# `@18f/identity-session`

Utilities for managing a user's session.

## Usage

### `requestSessionStatus`

Request the current session status.

```ts
import { requestSessionStatus } from '@18f/identity-session';

const { isLive, timeout } = await requestSessionStatus();
```

### `extendSession`

Request that the current session be kept alive.

```ts
import { extendSession } from '@18f/identity-session';

const { isLive, timeout } = await extendSession();
```
