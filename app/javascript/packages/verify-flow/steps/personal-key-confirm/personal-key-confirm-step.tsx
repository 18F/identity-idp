import { useContext } from 'react';
import type { FormEventHandler } from 'react';
import { Button } from '@18f/identity-components';
import { FormStepsContext, FormStepsContinueButton } from '@18f/identity-form-steps';
import { t } from '@18f/identity-i18n';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { Modal } from '@18f/identity-modal';
import { getAssetPath } from '@18f/identity-assets';
import PersonalKeyStep from '../personal-key/personal-key-step';
import PersonalKeyInput from './personal-key-input';
import type { VerifyFlowValues } from '../..';

interface PersonalKeyConfirmStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PersonalKeyConfirmStep(stepProps: PersonalKeyConfirmStepProps) {
  const { toNextStep } = useContext(FormStepsContext);
  const { registerField, value, toPreviousStep } = stepProps;
  const personalKey = value.personalKey!;

  const onFieldSubmit: FormEventHandler = (event) => {
    event.preventDefault();
    toNextStep();
  };

  return (
    <>
      <FormStepsContext.Provider
        value={{ isLastStep: false, toNextStep() {}, onPageTransition() {} }}
      >
        <PersonalKeyStep {...stepProps} />
      </FormStepsContext.Provider>
      <Modal onRequestClose={toPreviousStep}>
        <div className="pin-top pin-x display-flex flex-column flex-align-center top-neg-3">
          <img alt="" height="60" width="60" src={getAssetPath('p-key.svg')} />
        </div>
        <Modal.Heading>{t('forms.personal_key.title')}</Modal.Heading>
        <Modal.Description>{t('forms.personal_key.instructions')}</Modal.Description>
        <form onSubmit={onFieldSubmit}>
          <PersonalKeyInput
            expectedValue={personalKey}
            ref={registerField('personalKeyConfirmation')}
          />
        </form>
        <div className="grid-row grid-gap margin-top-5">
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
