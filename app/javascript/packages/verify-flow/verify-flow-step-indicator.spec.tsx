import { render } from '@testing-library/react';
import { StepStatus } from '@18f/identity-step-indicator';
import { AddressVerificationMethodContextProvider } from './context/address-verification-method-context';
import VerifyFlowStepIndicator, { getStepStatus } from './verify-flow-step-indicator';

describe('getStepStatus', () => {
  it('returns incomplete if step is after current step', () => {
    const result = getStepStatus(1, 0);

    expect(result).to.equal(StepStatus.INCOMPLETE);
  });

  it('returns current if step is current step', () => {
    const result = getStepStatus(1, 1);

    expect(result).to.equal(StepStatus.CURRENT);
  });

  it('returns complete if step is before current step', () => {
    const result = getStepStatus(0, 1);

    expect(result).to.equal(StepStatus.COMPLETE);
  });
});

describe('VerifyFlowStepIndicator', () => {
  it('renders step indicator for the current step', () => {
    const { getByText } = render(<VerifyFlowStepIndicator currentStep="personal_key" />);

    const current = getByText('step_indicator.flows.idv.secure_account');
    expect(current.closest('.step-indicator__step--current')).to.exist();

    const previous = getByText('step_indicator.flows.idv.verify_phone_or_address');
    expect(previous.closest('.step-indicator__step--complete')).to.exist();
  });

  context('with gpo as address verification method', () => {
    it('renders address verification as pending', () => {
      const { getByText } = render(
        <AddressVerificationMethodContextProvider initialMethod="gpo">
          <VerifyFlowStepIndicator currentStep="personal_key" />
        </AddressVerificationMethodContextProvider>,
      );

      const previous = getByText('step_indicator.flows.idv.verify_phone_or_address');
      expect(previous.closest('.step-indicator__step--pending')).to.exist();
    });
  });
});
