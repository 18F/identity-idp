import { useContext } from 'react';
import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import FormStepsContext from './form-steps-context';

function FormStepsContinueButton() {
  const { t } = useI18n();
  const { isLastStep } = useContext(FormStepsContext);

  return (
    <Button type="submit" isBig isWide className="display-block margin-y-5">
      {isLastStep ? t('forms.buttons.submit.default') : t('forms.buttons.continue')}
    </Button>
  );
}

export default FormStepsContinueButton;
