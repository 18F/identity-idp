# `@18f/identity-print-button`

Custom element and React implementation for a print button component.

## Usage

### Custom Element

Importing the element will register the `<lg-print-button>` custom element:

```ts
import '@18f/identity-print-button/print-button-element';
```

The custom element will implement the behavior to show a print dialog upon click, but all markup must already exist, rendered server-side or by the included React component.

```html
<lg-print-button>
  <button type="button">Print</button>
</lg-print-button>
```

### React

The package exports a `PrintButton` component, which extends the `Button` component from `@18f/identity-components`.

```tsx
import { PrintButton } from '@18f/identity-print-button';

export function Example() {
  return (
    <PrintButton isOutline />
  );
}
```
