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
