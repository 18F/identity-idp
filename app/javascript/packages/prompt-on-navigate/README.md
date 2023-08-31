# `@18f/identity-prompt-on-navigate`

Configures an `onbeforeunload` event handler such that the browser will prompt the user before they reload or navigate away from the page.

## Usage

```js
import { promptOnNavigate } from "@18f/identity-prompt-on-navigate";

// Set the onbeforeunload event handler.
const cleanUp = promptOnNavigate();

// ...some time later, call cleanUp() to restore any previous onbeforeunload handler and cancel any pending timers (this is important).
cleanUp();
```

## Analytics

By default, `promptOnNavigate` will call `trackEvent` to log a `User prompted before navigation` event when the onbeforeunload handler is called. It will then log `User prompted before navigation and still on page` events at 5, 15, and 30 seconds after the onbeforeunload handler is called (the `seconds` property on the event will contain the number of seconds since the initial prompt).

You can customize these intervals by passing a `stillOnPageIntervalsInSeconds` option:

```js
promptOnNavigate({
  // Log a 'User prompted before navigation and still on page' event 7 and 11 seconds after the initial prompt.
  stillOnPageIntervalsInSeconds: [7, 11],
});
```
