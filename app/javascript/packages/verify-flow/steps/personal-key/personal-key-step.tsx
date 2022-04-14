import { PageHeading, Button } from '@18f/identity-components';
import { ClipboardButton } from '@18f/identity-clipboard-button';
import { t } from '@18f/identity-i18n';
import { formatHTML } from '@18f/identity-react-i18n';
import { FormStepsContinueButton } from '@18f/identity-form-steps';
import type { FormStepComponentProps } from '@18f/identity-form-steps';
import type { VerifyFlowValues } from '../..';

interface PersonalKeyStepProps extends FormStepComponentProps<VerifyFlowValues> {}

function PersonalKeyStep({ value }: PersonalKeyStepProps) {
  const personalKey = value.personalKey!;

  return (
    <>
      <PageHeading>{t('headings.personal_key')}</PageHeading>
      <p>{t('instructions.personal_key.info')}</p>
      <div className="full-width-box margin-y-5">
        <div className="border-y border-primary-light bg-primary-lightest padding-y-3 text-center">
          <h2 className="margin-y-0">{t('users.personal_key.header')}</h2>
          <div className="bg-personal-key padding-top-4 margin-y-2">
            <div className="padding-x-0 tablet:padding-x-1 padding-y-2 separator-text bg-pk-box">
              {personalKey.split('-').map((segment) => (
                <strong key={segment} className="separator-text__code">
                  {segment}
                </strong>
              ))}
            </div>
          </div>
          <p className="margin-y-0">
            {formatHTML(
              t('users.personal_key.generated_on_html', {
                date: `<strong>${new Intl.DateTimeFormat([], {
                  dateStyle: 'long',
                }).format()}</strong>`,
              }),
              { strong: 'strong' },
            )}
          </p>
        </div>
      </div>
      <Button isOutline className="margin-right-2 margin-bottom-2 tablet:margin-bottom-0">
        {t('forms.backup_code.download')}
      </Button>
      <Button isOutline className="margin-right-2 margin-bottom-2 tablet:margin-bottom-0">
        {t('users.personal_key.print')}
      </Button>
      <ClipboardButton
        clipboardText="0000-0000-0000-0000"
        isOutline
        className="margin-bottom-2 tablet:margin-bottom-0"
      >
        {t('components.clipboard_button.label')}
      </ClipboardButton>
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
