# `@18f/identity-input-validation`

Custom element and helpers for enhanced form input behavior: phone number
formatting, password visibility toggling, and constraint-based validation.

## Usage

Importing the package registers an `input-element` custom element and its
supporting behavior as a side effect:

```ts
import '@18f/identity-input-validation/input-element';
```

The element enhances markup emitted by `NDS::InputComponent`. It looks for
inputs and controls by data attribute hooks:

```html
<div class="usa-input" data-nds-validation-messages="{…}">
  <label for="user_phone">Phone number</label>
  <div class="usa-input__phone-shell">
    <select data-nds-phone-country>…</select>
    <input type="tel" data-nds-phone-input id="user_phone" />
  </div>
  <p class="usa-input__error" data-nds-error aria-live="polite">
    <span class="usa-input__error-inner"></span>
  </p>
</div>
```

## Behavior

- **Phone formatting:** inputs marked `data-nds-phone-input` are formatted with
  `libphonenumber-js` `AsYouType` as the user types, keyed to the country chosen
  in the associated `data-nds-phone-country` select.
- **Password toggle:** a `data-nds-password-toggle` button shows and hides the
  password, keeping the `data-nds-password-icon-show` / `data-nds-password-icon-hide`
  icons and its accessible label in sync. Related toggles in the same form
  (password and confirmation) stay in sync.
- **Validation:** on blur and on form submit, controls are validated against
  their constraints and the messages in `data-nds-validation-messages`, rendering
  errors into the `data-nds-error` region without the native validation UI.
- **Submit gating:** submit buttons in the form are disabled until the form's
  constraints are satisfied.
- **Overflow fade:** long input values fade at the scrollable edges.
