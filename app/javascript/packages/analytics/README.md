# `@18f/identity-analytics`

Utilities for logging events and errors in the application.

By default, events logged from the frontend will have their names prefixed with "Frontend:". This
behavior occurs in [`FrontendLogController`][frontend_log_controller.rb]. You can avoid the prefix
by assigning an event mapping method in the controller's `EVENT_MAP` constant.

[frontend_log_controller.rb]: https://github.com/18F/identity-idp/blob/main/app/controllers/frontend_log_controller.rb

## Example

```ts
import { trackEvent, trackError } from '@18f/identity-analytics';

button.addEventListener('click', () => {
  trackEvent('Button clicked', { success: true });
});

try {
  doSomethingRisky();
} catch (error) {
  trackError(error);
}
```
