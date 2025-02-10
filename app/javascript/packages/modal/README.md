# `@18f/identity-modal`

Custom element for a modal dialog.

## Usage

Importing the element will register the `<lg-modal>` custom element:

```ts
import '@18f/identity-modal/modal-element';
```

The custom element will implement modal behavior, including focus trap and a programmatic interface for showing and dismissing the modal.

However, all markup must already exist.

```html
<lg-modal>
  <dialog
    class="modal__content"
    aria-describedby="modal-description-7ace89e6"
    aria-labelledby="modal-label-7ace89e6"
  >
    <h2 id="modal-label-7ace89e6">
      Modal Heading
    </h2>
    Modal Content
  </dialog>
</lg-modal>
```

## API

### `ModalElement#show`

Shows the modal dialog.

### `ModalElement#hide`

Hides the modal dialog.
