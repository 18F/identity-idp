# `@18f/identity-validated-field`

Custom element and React component for controlling validation behavior associated with a form input.

It enhances the behavior of an input by:

- Displaying an error message on the page when form submission results in a validation error
- Moving focus to the first invalid field when form submission results in a validation error
- Providing default error messages for common validation constraints (e.g. required field missing)
- Allowing you to customize error messages associated with default field validation
- Resetting the error state when an input value changes

## Usage

### Custom Element

Importing the element will register the `<lg-validated-field>` custom element:

```ts
import '@18f/identity-validated-field/validated-field-element';
```

The custom element will implement associated behaviors, but all markup must already exist, rendered server-side or by the included React component.

```html
<lg-validated-field error-id="validated-field-error-b6a88605">
  <script type="application/json" class="validated-field__error-strings">{"valueMissing":"This field is required"}</script>
  <div class="validated-field__input-wrapper">
    <input class="validated-field__input" aria-invalid="false" required="required">
  </div>
</lg-validated-field>
```

### React

The package exports a `<ValidatedField />` component. If rendered without a child, it will render a text input by default.

```tsx
import { render } from 'react-dom';
import { ValidatedField } from '@18f/identity-validated-field';

const appRoot = document.getElementById('app-root');

render(<ValidatedField />, appRoot);
```
