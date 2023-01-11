import { t } from '@18f/identity-i18n';

export enum StepStatus {
  CURRENT,
  COMPLETE,
  INCOMPLETE,
}

export interface StepIndicatorStepProps {
  /**
   * Step name.
   */
  title: string;

  /**
   * Step status.
   */
  status: StepStatus;
}

function StepIndicatorStep({ title, status }: StepIndicatorStepProps) {
  const { CURRENT, COMPLETE, INCOMPLETE } = StepStatus;

  const classes = [
    'step-indicator__step',
    status === CURRENT && 'step-indicator__step--current',
    status === COMPLETE && 'step-indicator__step--complete',
  ]
    .filter(Boolean)
    .join(' ');

  let statusText;
  switch (status) {
    case COMPLETE:
      statusText = t('step_indicator.status.complete');
      break;
    case INCOMPLETE:
      statusText = t('step_indicator.status.not_complete');
      break;
    default:
      statusText = t('step_indicator.status.current');
  }

  return (
    <li className={classes}>
      <span className="step-indicator__step-title">{title}</span>
      <span className="usa-sr-only">{statusText}</span>
    </li>
  );
}

export default StepIndicatorStep;
