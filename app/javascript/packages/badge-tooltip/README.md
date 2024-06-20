# `@18f/identity-badge-tooltip`

Custom element for a badge component.

## Usage

### Custom Element

Importing the element will register the `<lg-badge-tooltip>` custom element:

```ts
import '@18f/identity-badge-tooltip/badge-tooltip-element';
```

```html
<lg-badge-tooltip tooltip-text="Your identity has been verified.">
  <span class="usa-tooltip">
    <div class="lg-verification-badge usa-tooltip__trigger" data_position="top" type="badge" data-position="top" aria-describedby="tooltip-712979" tabindex="0">
      <span class="icon usa-icon text-success" id="icon-b48becfc"></span>
    </div>
  </span>
</lg-badge-tooltip>
```