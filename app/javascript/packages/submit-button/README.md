# `@18f/identity-submit-button`

Custom element for a submit button component.

## Usage

### Custom Element

Importing the element will register the `<lg-submit-button>` custom element:

```ts
import '@18f/identity-submit-button/submit-button-element';
```

The custom element will implement the behavior to activate a button upon associated form submission, but all markup must already exist.

```html
<form>
  <lg-submit-button>
    <button class="usa-button">Submit</button>
  </lg-submit-button>
</form>
```
