# `@18f/identity-webauthn`

Utilities and custom elements related to WebAuthn.

## Usage

### Custom Element

Importing the element will register the `<lg-webauthn-input>` custom element:

```ts
import '@18f/identity-webauthn/webauthn-input-element';
```

The custom element will implement behaviors associated with WebAuthn inputs, but all markup must already exist.

```html
<lg-webauthn-input platform hidden>
  <input type="checkbox" id="platform-authenticator">
  <label for="platform-authenticator">Platform authenticator</label>
</lg-webauthn-input>
```
