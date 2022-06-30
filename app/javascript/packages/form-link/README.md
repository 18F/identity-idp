# `@18f/identity-form-link`

Custom element for links which submit as a form, supporting non-GET navigation.

## Usage

### Custom Element

Importing the element will register the `<lg-form-link>` custom element:

```ts
import '@18f/identity-form-link/form-link-element';
```

The custom element will implement the link submission behavior, but all markup must already exist.

```html
<lg-form-link>
  <a href="https://example.com">Submit</a>
  <form method="post" action="https://example.com" class="display-none"></form>
</lg-form-link>
```
