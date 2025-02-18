# `@18f/identity-analytics`

Utilities and custom elements for logging events and errors in the application.

## Usage

### Programmatic Event Tracking

Track an event or error from your code using exported function members.

Since JavaScript may be bundled and minified in production environments, including an `errorId` is
required to uniquely identify the source of the error.

```ts
import { trackEvent, trackError } from '@18f/identity-analytics';

button.addEventListener('click', () => {
  trackEvent('button_clicked', { success: true });
});

try {
  doSomethingRisky();
} catch (error) {
  trackError(error, { errorId: 'exampleId' });
}
```

### HTML Element Click Tracking

Use the `<lg-click-observer>` custom element to record clicks within the element.

```ts
import '@18f/identity-analytics/click-observer-element';
```

The custom element will implement the analytics logging behavior, but all markup must already exist.

```html
<lg-click-observer event-name="button_clicked">
  <button type="button">Click me!</button>
</lg-click-observer>
```
