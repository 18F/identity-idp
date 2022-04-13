import { PageHeading, Button } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { FormStepsContinueButton } from '@18f/identity-form-steps';

function PersonalKeyStep() {
  return (
    <>
      <PageHeading>{t('headings.personal_key')}</PageHeading>
      <p>
        {t('instructions.personal_key.info_html', {
          accent: `<strong>t('instructions.personal_key.accent')}</strong>`,
        })}
      </p>
      <div className="full-width-box margin-y-5" />
      <Button className="margin-right-2 margin-bottom-2 tablet:margin-bottom-0" isOutline>
        {t('forms.backup_code.download')}
      </Button>
      <Button className="margin-right-2 margin-bottom-2 tablet:margin-bottom-0" isOutline>
        {t('users.personal_key.print')}
      </Button>
      <Button className="margin-bottom-2 tablet:margin-bottom-0" isOutline>
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
