# `@18f/identity-one-time-code-input`

Custom element implementation for a one-time code input.

## Usage

Importing the element will register the `<lg-one-time-code-input>` custom element:

```ts
import '@18f/identity-one-time-code-input/one-time-code-input-element';
```

The custom element will implement the behavior to receive the code for the credential transport, but all markup must already exist.

```html
<lg-one-time-code-input transport="sms">
  <label for="one-time-code-input-input-1">One-time code</label>
  <input name="code" id="one-time-code-input-input-1" class="one-time-code-input__input" />
</lg-one-time-code-input>
```
