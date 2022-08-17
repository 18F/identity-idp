# `@18f/identity-components`

React components for common UI interactions. These components are intended to be general-purpose and
reusable, whereas domain-specific React components should be found in the package corresponding to
the specific page or feature.

Many of these components are React implementations for components of the [Login.gov Design System](https://design.login.gov/).

## Example

```tsx
import { Button } from '@18f/identity-components';

function MyComponent() {
  return <Button isUnstyled>Continue</Button>;
}
```
