import { Alert, Button } from '@18f/identity-components';
import { FormStepsContext, FormStepsContinueButton } from '@18f/identity-form-steps';
import { t } from '@18f/identity-i18n';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { Modal } from '@18f/identity-modal';
import PersonalKeyStep from '../personal-key/personal-key-step';
import PersonalKeyInput from './personal-key-input';
import type { VerifyFlowValues } from '../..';

interface PersonalKeyConfirmStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PersonalKeyConfirmStep(stepProps: PersonalKeyConfirmStepProps) {
  const { registerField, errors, toPreviousStep } = stepProps;

  return (
    <>
      <FormStepsContext.Provider value={{ isLastStep: false, onPageTransition() {} }}>
        <PersonalKeyStep {...stepProps} />
      </FormStepsContext.Provider>
      <Modal>
        <Modal.Heading>{t('forms.personal_key.title')}</Modal.Heading>
        <Modal.Description>{t('forms.personal_key.instructions')}</Modal.Description>
        {errors.length > 0 && (
          <Alert type="error" className="margin-bottom-4">
            {t('users.personal_key.confirmation_error')}
          </Alert>
        )}
        <PersonalKeyInput ref={registerField('personalKeyConfirmation', { isRequired: true })} />
        <div className="grid-row grid-gap">
          <div className="grid-col-12 tablet:grid-col-6 margin-bottom-2 tablet:margin-bottom-0 tablet:display-none">
            <FormStepsContinueButton className="margin-y-0" />
          </div>
          <div className="grid-col-12 tablet:grid-col-6">
            <Button isBig isWide isOutline onClick={toPreviousStep}>
              {t('forms.buttons.back')}
            </Button>
          </div>
          <div className="grid-col-12 tablet:grid-col-6 margin-bottom-2 tablet:margin-bottom-0 display-none tablet:display-block">
            <FormStepsContinueButton className="margin-y-0" />
          </div>
        </div>
      </Modal>
    </>
  );
}

export default PersonalKeyConfirmStep;
