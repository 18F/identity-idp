import { render } from '@testing-library/react';
import { StepStatus } from '@18f/identity-step-indicator';
import VerifyFlowStepIndicator, {
  getStepStatus,
  VerifyFlowPath,
} from './verify-flow-step-indicator';

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

  context('with in-person flow path', () => {
    it('renders step indicator for the current step', () => {
      const { getByText } = render(
        <VerifyFlowStepIndicator currentStep="document_capture" path={VerifyFlowPath.IN_PERSON} />,
      );

      const current = getByText('step_indicator.flows.idv.find_a_post_office');
      expect(current.closest('.step-indicator__step--current')).to.exist();
    });
  });
});
