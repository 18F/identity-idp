# `@18f/identity-print-button`

Custom element for a print button component.

## Usage

### Custom Element

Importing the element will register the `<lg-print-button>` custom element:

```ts
import '@18f/identity-print-button/print-button-element';
```

The custom element will implement the behavior to show a print dialog upon click, but all markup must already exist.

```html
<lg-print-button>
  <button type="button">Print</button>
</lg-print-button>
```
