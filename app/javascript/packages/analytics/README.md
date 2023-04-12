# `@18f/identity-analytics`

Utilities and custom elements for logging events and errors in the application.

By default, events logged from the frontend will have their names prefixed with "Frontend:". This
behavior occurs in [`FrontendLogController`][frontend_log_controller.rb]. You can avoid the prefix
by assigning an event mapping method in the controller's `EVENT_MAP` constant.

[frontend_log_controller.rb]: https://github.com/18F/identity-idp/blob/main/app/controllers/frontend_log_controller.rb

## Usage

### Programmatic Event Tracking

Track an event or error from your code using exported function members.

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

### HTML Element Click Tracking

Use the `<lg-click-observer>` custom element to record clicks within the element.

```ts
import '@18f/identity-analytics/click-observer-element';
```

The custom element will implement the analytics logging behavior, but all markup must already exist.

```html
<lg-click-observer event-name="Button clicked">
  <button type="button">Click me!</button>
</lg-click-observer>
```
