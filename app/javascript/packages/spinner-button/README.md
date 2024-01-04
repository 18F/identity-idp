# `@18f/identity-spinner-button`

Custom element and React component for displaying a spinner effect on a button when clicked.

## Usage

### Custom Element

Importing the element will register the `<lg-spinner-button>` custom element:

```ts
import '@18f/identity-spinner-button/spinner-button-element';
```

The custom element will implement associated behaviors, but all markup must already exist, rendered server-side or by the included React component.

When clicked, the a `spinner-button--spinner-active` class will be added to the root element, which can be used to control the visibility of associated elements using custom CSS styles.

```html
<lg-spinner-button long-duration-wait-ms="15000">
  <button>
    <span class="spinner-button__content">Click Me</span>
  </button>
</lg-spinner-button>
```

### React

The package exports a `<SpinnerButton />` component.

```tsx
import { render } from 'react-dom';
import { SpinnerButton } from '@18f/identity-spinner-button';

const appRoot = document.getElementById('app-root');

render(<SpinnerButton>Spin!</SpinnerButton>, appRoot)
```
