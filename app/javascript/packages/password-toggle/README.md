# `@18f/identity-password-toggle`

Custom element implementation that toggles the visibility of a password field text in response to clicking a checkbox.

## Usage

Importing the element will register the `<lg-password-toggle>` custom element:

```ts
import '@18f/identity-password-toggle/password-toggle-element';
```

The custom element will implement associatd behaviors, but all markup must already exist.

```html
<lg-password-toggle>
  <label for="password">Password</label>
  <input id="password" class="password-toggle__input">
  <input id="toggle" type="checkbox" class="password-toggle__toggle" aria-controls="password">
  <label for="toggle" class="password-toggle__toggle-label">Show password</label>
</lg-password-toggle>
```
