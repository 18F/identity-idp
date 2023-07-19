# `@18f/identity-session`

Utilities and custom elements for managing a user's session.

## Usage

### API

#### `requestSessionStatus`

Request the current session status.

```ts
import { requestSessionStatus } from '@18f/identity-session';

const { isLive, timeout } = await requestSessionStatus();
```

#### `extendSession`

Request that the current session be kept alive.

```ts
import { extendSession } from '@18f/identity-session';

const { isLive, timeout } = await extendSession();
```

### Custom Elements

#### Session Timeout Modal

Use the `<lg-session-timeout-modal>` custom element to handle the display, status fetching, and redirect behavior associated with session timeout.

```ts
import '@18f/identity-session/session-timeout-modal-element';
```

The custom element will implement associated behaviors, but all markup must already exist.

```html
<lg-session-timeout-modal warning-offset-in-seconds="120" timeout="2023-01-01T00:00:00Z">
  <lg-modal>
    <button class="lg-session-timeout-modal__keep-alive-button">
      Stay Signed In
    </button>
    <button class="lg-session-timeout-modal__sign-out-button">
      Sign Out
    </button>
  </lg-modal>
</lg-session-timeout-modal>
```

