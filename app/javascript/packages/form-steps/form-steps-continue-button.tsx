import { useContext } from 'react';
import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import FormStepsContext from './form-steps-context';

interface FormStepsContinueButtonProps {
  /**
   * Optional additional class names to apply to button.
   */
  className?: string;
}

function FormStepsContinueButton({ className }: FormStepsContinueButtonProps) {
  const { t } = useI18n();
  const { isLastStep, toNextStep } = useContext(FormStepsContext);

  const classes = ['display-block', 'margin-y-5', className].filter(Boolean).join(' ');

  return (
    <Button onClick={toNextStep} isBig isWide className={classes}>
      {isLastStep ? t('forms.buttons.submit.default') : t('forms.buttons.continue')}
    </Button>
  );
}

export default FormStepsContinueButton;
