import { forwardRef } from 'react';
import { t } from '@18f/identity-i18n';

function PersonalKeyInput(_props, ref) {
  return (
    <input
      ref={ref}
      aria-label={t('forms.personal_key.confirmation_label')}
      autoComplete="off"
      className="width-full margin-bottom-6 border-dashed field font-family-mono personal-key text-uppercase"
      maxLength={16}
      pattern="[a-zA-Z0-9-]"
      spellCheck={false}
      type="text"
    />
  );
}

export default forwardRef(PersonalKeyInput);
