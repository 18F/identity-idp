# `@18f/identity-clipboard-button`

Custom element for a clipboard button component.

## Usage

### Custom Element

Importing the element will register the `<lg-clipboard-button>` custom element:

```ts
import '@18f/identity-clipboard-button/clipboard-button-element';
```

The custom element will implement the copying behavior, but all markup must already exist.

```html
<lg-clipboard-button clipboard-text="text to copy" tooltip-text="Copied!">
  <button type="button">Copy</button>
</lg-clipboard-button>
```
