# `@18f/identity-clipboard-button`

Custom element and React implementation for a clipboard button component.

## Usage

### Custom Element

Importing the element will register the `<lg-clipboard-button>` custom element:

```ts
import '@18f/identity-clipboard-button/clipboard-button-element';
```

The custom element will implement the copying behavior, but all markup must already exist, rendered server-side or by the included React component.

```html
<lg-clipboard-button data-clipboard-text="text to copy">
  <button type="button">Copy</button>
</lg-clipboard-button>
```

### React

The package exports a `ClipboardButton` component, which extends the `Button` component from `@18f/identity-components` with an additional `clipboardText` prop.

```tsx
import { ClipboardButton } from '@18f/identity-clipboard-button';

export function Example() {
  return (
    <ClipboardButton clipboardText="text to copy" />
  );
}
```
