# `@18f/identity-nds-password-strength`

Custom element implementation that displays a password strength meter and feedback for an associated password input, for use in the NDS bucket.

## Usage

Importing the element registers the `<lg-nds-password-strength>` custom element:

```ts
import '@18f/identity-nds-password-strength/password-strength-element';
```

The custom element implements interactive behavior; all markup must already exist. It scores the associated input with [zxcvbn], reveals the meter as the user types, keeps the input's `aria-describedby` in sync with the feedback, and sets custom validity when the password is not strong enough.

```html
<lg-nds-password-strength
  input-id="password-input"
  minimum-length="12"
  forbidden-passwords="[]"
  class="password-strength"
  data-open="false"
  hidden
>
  <div class="password-strength__inner">
    <div class="password-strength__row">
      <div class="password-strength__track" aria-hidden="true">
        <span class="password-strength__bar"></span>
      </div>
      <p
        class="password-strength__feedback"
        id="password-input-password-strength"
        aria-live="polite"
      ></p>
    </div>
  </div>
</lg-nds-password-strength>
```

[zxcvbn]: https://github.com/dropbox/zxcvbn
