# `@18f/password-strength`

Custom element implementation that displays a strength meter and feedback for an associated password input element.

## Usage

Importing the element will register the `<lg-password-strength>` custom element:

```ts
import '@18f/password-strength/password-strength-element';
```

The custom element will implement interactive behaviors, but all markup must already exist.

```html
<lg-password-strength
  input-id="password-input"
  minimum-length="12"
  forbidden-passwords="[]"
  class="display-none"
>
  <div class="password-strength__meter">
    <div class="password-strength__meter-bar"></div>
    <div class="password-strength__meter-bar"></div>
    <div class="password-strength__meter-bar"></div>
    <div class="password-strength__meter-bar"></div>
  </div>
  Password strength:
  <span class="password-strength__strength"></span>
  <div class="password-strength__feedback"></div>
</lg-password-strength>
```
