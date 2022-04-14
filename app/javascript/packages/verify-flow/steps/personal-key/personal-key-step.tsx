import { PageHeading, Button } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { FormStepsContinueButton } from '@18f/identity-form-steps';

function PersonalKeyStep() {
  return (
    <>
      <PageHeading>{t('headings.personal_key')}</PageHeading>
      <p>{t('instructions.personal_key.info')}</p>
      <div className="full-width-box margin-y-5" />
      <Button isOutline className="margin-right-2 margin-bottom-2 tablet:margin-bottom-0">
        {t('forms.backup_code.download')}
      </Button>
      <Button isOutline className="margin-right-2 margin-bottom-2 tablet:margin-bottom-0">
        {t('users.personal_key.print')}
      </Button>
      <Button isOutline className="margin-bottom-2 tablet:margin-bottom-0">
        {t('links.copy')}
      </Button>
      <div className="margin-y-5 clearfix">
        <p className="margin-bottom-0">
          <strong>{t('instructions.personal_key.email_title')}</strong>
        </p>
        <p>{t('instructions.personal_key.email_body')}</p>
      </div>
      <FormStepsContinueButton />
    </>
  );
}

export default PersonalKeyStep;
