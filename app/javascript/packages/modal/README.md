# `@18f/identity-modal`

Wires native `<dialog data-ads-modal>` dialogs (backdrop click, Escape, focus return).

## Usage

```ts
import '@18f/identity-modal';
// or
import '@18f/identity-modal/modal';
```

`ModalComponent` already imports the package via its sidecar script. Markup uses
`data-ads-modal`, `data-ads-modal-open`, and `data-ads-modal-close`.
