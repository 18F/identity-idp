import { Button } from '@18f/identity-components';
import { FormStepsButton } from '@18f/identity-form-steps';
import { t } from '@18f/identity-i18n';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import { Modal } from '@18f/identity-modal';
import { getAssetPath } from '@18f/identity-assets';
import { trackEvent } from '@18f/identity-analytics';
import PersonalKeyStep from '../personal-key/personal-key-step';
import PersonalKeyInput from './personal-key-input';
import type { VerifyFlowValues } from '../../verify-flow';

interface PersonalKeyConfirmStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PersonalKeyConfirmStep(stepProps: PersonalKeyConfirmStepProps) {
  const { registerField, value, onChange, toPreviousStep } = stepProps;
  const personalKey = value.personalKey!;

  const closeModalActions = () => {
    trackEvent('IdV: hide personal key modal');
    toPreviousStep();
  };

  return (
    <>
      <PersonalKeyStep {...stepProps} />
      <Modal onRequestClose={closeModalActions}>
        <div className="pin-top pin-x display-flex flex-column flex-align-center top-neg-3">
          <img
            alt={t('idv.titles.personal_key')}
            height="60"
            width="60"
            src={getAssetPath('p-key.svg')}
          />
        </div>
        <Modal.Heading>{t('forms.personal_key.title')}</Modal.Heading>
        <Modal.Description>{t('forms.personal_key.instructions')}</Modal.Description>
        {/* Because the Modal renders into a portal outside the flow form, inputs would not normally
            emit a submit event. We can reinstate the expected behavior with an empty form. A submit
            event will bubble through the React portal boundary and be handled by FormSteps. Because
            the form is not rendered in the same DOM hierarchy, it is not invalid nesting. */}
        <form noValidate>
          <PersonalKeyInput
            expectedValue={personalKey}
            ref={registerField('personalKeyConfirm')}
            onChange={(personalKeyConfirm) => onChange({ personalKeyConfirm })}
          />
          <div className="grid-row grid-gap margin-top-5">
            <div className="grid-col-12 tablet:grid-col-6 margin-bottom-2 tablet:margin-bottom-0 tablet:display-none">
              <FormStepsButton.Continue className="margin-y-0" />
            </div>
            <div className="grid-col-12 tablet:grid-col-6">
              <Button isBig isWide isOutline onClick={closeModalActions}>
                {t('forms.buttons.back')}
              </Button>
            </div>
            <div className="grid-col-12 tablet:grid-col-6 margin-bottom-2 tablet:margin-bottom-0 display-none tablet:display-block">
              <FormStepsButton.Continue className="margin-y-0" />
            </div>
          </div>
        </form>
      </Modal>
    </>
  );
}

export default PersonalKeyConfirmStep;
