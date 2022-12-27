# `@18f/identity-download-button`

Custom element for a download button component.

## Usage

Importing the element will register the `<lg-download-button>` custom element:

```ts
import '@18f/identity-download-button/download-button-element';
```

The custom element will implement the copying behavior, but all markup must already exist.

```html
<lg-download-button>
  <a href="data:text/plain;charset=utf-8,hello%20world" download="filename.txt">Download</a>
</lg-download-button>
```
