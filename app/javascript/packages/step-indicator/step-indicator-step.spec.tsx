import { render } from '@testing-library/react';
import StepIndicatorStep, { StepStatus } from './step-indicator-step';

describe('StepIndicatorStep', () => {
  context('current step', () => {
    it('renders step', () => {
      const { getByText } = render(<StepIndicatorStep title="Step" status={StepStatus.CURRENT} />);

      const title = getByText('Step');
      const status = getByText('step_indicator.status.current');
      const step = title.closest('.step-indicator__step')!;

      expect(title).to.be.ok();
      expect(status).to.be.ok();
      expect(step.classList.contains('step-indicator__step--current')).to.be.true();
      expect(step.classList.contains('step-indicator__step--complete')).to.be.false();
      expect(status.classList.contains('step-indicator__step-subtitle')).to.be.false();
      expect(status.classList.contains('usa-sr-only')).to.be.true();
    });
  });

  context('complete step', () => {
    it('renders step', () => {
      const { getByText } = render(<StepIndicatorStep title="Step" status={StepStatus.COMPLETE} />);

      const title = getByText('Step');
      const status = getByText('step_indicator.status.complete');
      const step = title.closest('.step-indicator__step')!;

      expect(title).to.be.ok();
      expect(status).to.be.ok();
      expect(step.classList.contains('step-indicator__step--current')).to.be.false();
      expect(step.classList.contains('step-indicator__step--complete')).to.be.true();
      expect(status.classList.contains('step-indicator__step-subtitle')).to.be.false();
      expect(status.classList.contains('usa-sr-only')).to.be.true();
    });
  });

  context('incomplete step', () => {
    it('renders step', () => {
      const { getByText } = render(
        <StepIndicatorStep title="Step" status={StepStatus.INCOMPLETE} />,
      );

      const title = getByText('Step');
      const status = getByText('step_indicator.status.current');
      const step = title.closest('.step-indicator__step')!;

      expect(title).to.be.ok();
      expect(status).to.be.ok();
      expect(step.classList.contains('step-indicator__step--current')).to.be.false();
      expect(step.classList.contains('step-indicator__step--complete')).to.be.false();
      expect(status.classList.contains('step-indicator__step-subtitle')).to.be.false();
      expect(status.classList.contains('usa-sr-only')).to.be.true();
    });
  });
});
