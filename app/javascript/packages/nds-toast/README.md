# `@18f/identity-nds-toast`

Custom element for the NDS toast notification.

## Usage

Importing the element will register the `<lg-toast>` custom element:

```ts
import '@18f/identity-nds-toast/toast-element';
```

The custom element implements the toast behavior, but all markup must already
exist. Rendering is typically handled by `NDS::ToastComponent`.

```html
<lg-toast class="toast" data-open="false" data-show-delay="500" data-dismiss-after="3000">
  <div class="toast__announcement" data-nds-toast-announcement>
    <span class="toast__icon" aria-hidden="true"><!-- icon --></span>
    <p class="toast__text">Your changes were saved.</p>
  </div>
</lg-toast>
```

After `data-show-delay` milliseconds the element reveals the toast, marks the
announcement region live, and (when `data-dismiss-after` is greater than zero)
schedules an automatic dismissal that many milliseconds later. Clicking the
toast dismisses it immediately. The dismissal animation is skipped when the
user prefers reduced motion.
