import sinon from 'sinon';
import { render } from '@testing-library/react';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import withPresenceValidation from './with-presence-validation';

describe('withPresenceValidation', () => {
  type FormValues = { example: string };
  const DEFAULT_PROPS = {
    onChange() {},
    onError() {},
    errors: [],
    toPreviousStep() {},
    registerField: () => () => {},
    unknownFieldErrors: [],
    value: {} as FormValues,
  };
  interface ComponentProps extends FormStepComponentProps<FormValues> {
    value: Partial<FormValues> & { example: string };
  }
  function Component({ value }: ComponentProps) {
    return <>{value.example.toString()}</>;
  }
  const EnhancedComponent = withPresenceValidation(Component, 'example');

  context('if the value is not present', () => {
    it('renders nothing', () => {
      const { container } = render(<EnhancedComponent {...DEFAULT_PROPS} />);

      expect(container.innerHTML).to.be.empty();
    });

    it('calls toPreviousStep', () => {
      const toPreviousStep = sinon.spy();
      render(<EnhancedComponent {...DEFAULT_PROPS} toPreviousStep={toPreviousStep} />);

      expect(toPreviousStep).to.have.been.calledOnce();
    });
  });

  context('if the value is present', () => {
    it('renders the default component implementation result', () => {
      const { getByText } = render(
        <EnhancedComponent {...DEFAULT_PROPS} value={{ example: 'present' }} />,
      );

      expect(getByText('present')).to.be.ok();
    });
  });
});
