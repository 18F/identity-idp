# `@18f/identity-form-steps`

React components for managing a user's progression through a series of steps in a form.

## Usage

At a minimum, render the `<FormSteps />` React component with an array of step configurations. Each step must include a `name` and `form`, where the `form` is a React component that will be rendered once the user reaches the step.

```tsx
import { render } from 'react-dom';
import { FormSteps } from '@18f/identity-form-steps';

const STEPS = [
  { name: 'First Step', form: () => <p>Welcome to the first step!</p> },
  { name: 'Second Step', form: () => <p>Welcome to the second step!</p> },
];

const appRoot = document.getElementById('app-root');

render(<FormSteps steps={STEPS} />, appRoot);
```
