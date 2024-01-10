# `@18f/identity-password-confirmation`

Custom element implementation that adds password inputs with validation for confirmation.

## Usage

Importing the element will register the `<lg-password-confirmation>` custom element:

```ts
import '@18f/identity-password-confirmation/password-confirmation-element';
```

The custom element will implement the behavior for validation, but all markup must already exist.

```html
<lg-password-confirmation>
  <label for="input-1">Password</label>
  <input id="input-1" class="password-confirmation__input">
  <label for="input-1b">Confirm password</label>
  <input id="input-1b" class="password-confirmation__input-confirmation">
  <div class="password-confirmation__toggle-wrapper">
    <input
      id="toggle-1"
      type="checkbox"
      class="password-confirmation__toggle"
      aria-controls="input-1"
    >
    <label for="toggle-1" class="usa-checkbox__label password-confirmation__toggle-label">
      Show password
    </label>
  </div>`;
</lg-password-confirmation>
```
