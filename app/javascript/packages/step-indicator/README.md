# `@18f/identity-step-indicator`

Custom element and React implementation for a step indicator UI component.

## Usage

### Custom Element

Importing the element will register the `<lg-step-indicator>` custom element:

```ts
import '@18f/identity-step-indicator/step-indicator-element';
```

The custom element will implement the small viewport scroll behavior, but all markup must already exist, rendered server-side or by the included React component.

```html
<lg-step-indicator role="region" aria-label="Step progress">
  <ol class="step-indicator__scroller">
    <li class="step-indicator__step step-indicator__step--completed">
      <span class="step-indicator__step-title">
        Step 1
      </span>
    </li>
    <li class="step-indicator__step step-indicator__step--current">
      <span class="step-indicator__step-title">
        Step 2
      </span>
    </li>
    <li class="step-indicator__step">
      <span class="step-indicator__step-title">
        Step 3
      </span>
    </li>
  </ol>
</lg-step-indicator>
```

### React

The package exports two components, `StepIndicator` and `StepIndicatorStep`, along with an enum of status values, `StepStatus`.

```tsx
import { StepIndicator, StepIndicatorStep, StepStatus } from '@18f/identity-step-indicator';

export function VerifyFlow() {
  return (
    <StepIndicator>
      <StepIndicatorStep title="Step 1" status={StepStatus.COMPLETE} />
      <StepIndicatorStep title="Step 2" status={StepStatus.CURRENT} />
      <StepIndicatorStep title="Step 3" status={StepStatus.INCOMPLETE} />
    </StepIndicator>
  );
}
```
