# `@18f/identity-modal`

Custom element and React implementation for a print button component.

## Usage

### Custom Element

_The modal custom element is not currently implemented._

### React

The package exports a named `Modal` component, which includes several helper components available as properties of the top-level component:

- `Modal`: The top-level wrapper component.
- `Modal.Heading`: Modal heading.
- `Modal.Description`: Optional modal description.

```tsx
import { Button } from '@18f/identity-components';
import { Modal } from '@18f/identity-modal';

export function Example() {
  return (
    <Modal onSubmit={() => {}} onClose={() => {}}>
      <Modal.Heading>Are you sure you want to continue?</Modal.Heading>
      <Modal.Description>You have unsaved changes that will be lost.</Modal.Description>
      <Button>Continue</Button>
      <Button isOutline>Go Back</Button>
    </Modal>
  );
}
```
