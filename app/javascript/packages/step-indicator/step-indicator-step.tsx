import { t } from '@18f/identity-i18n';

export enum StepStatus {
  CURRENT,
  COMPLETE,
  PENDING,
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
  const { CURRENT, COMPLETE, PENDING } = StepStatus;

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
    case PENDING:
      statusText = t('step_indicator.status.pending');
      break;
    default:
      statusText = t('step_indicator.status.current');
  }

  return (
    <li className={classes}>
      <span className="step-indicator__step-title">{title}</span>
      <span className={status === PENDING ? 'step-indicator__step-subtitle' : 'usa-sr-only'}>
        {statusText}
      </span>
    </li>
  );
}

export default StepIndicatorStep;
