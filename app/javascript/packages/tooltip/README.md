# `@18f/identity-tooltip`

Custom element for a tooltip component.

## Usage

Importing the element will register the `<lg-tooltip>` custom element:

```ts
import '@18f/identity-tooltip/tooltip-element';
```

The custom element will implement behaviors for showing tooltip text on hover or focus, but all markup must already exist.

> [!WARNING]
> Due to existing issues with the U.S. Web Design System Tooltip component, there are a few limitations to be aware of:
> 1. Content must be wrapped in a wrapper element, such as a `<span>` tag.
> 2. Any other nested child elements must be non-interactive, using `pointer-events: none;`.

```html
<lg-tooltip tooltip-text="Your identity has been verified.">
  <span>Verified</span>
</lg-tooltip>
```
