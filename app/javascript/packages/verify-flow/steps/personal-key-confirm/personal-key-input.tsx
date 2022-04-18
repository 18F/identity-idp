import { forwardRef } from 'react';
import Cleave from 'cleave.js/react';
import { t } from '@18f/identity-i18n';

/**
 * Maximum length of personal key value, including delimiters.
 */
const CODE_LENGTH = 19;

function PersonalKeyInput(_props, ref) {
  return (
    <Cleave
      options={{
        blocks: [4, 4, 4, 4],
        delimiter: '-',
      }}
      ref={ref}
      aria-label={t('forms.personal_key.confirmation_label')}
      autoComplete="off"
      className="width-full margin-bottom-6 field font-family-mono text-uppercase"
      maxLength={CODE_LENGTH}
      pattern="[a-zA-Z0-9-]"
      spellCheck={false}
      type="text"
    />
  );
}

export default forwardRef(PersonalKeyInput);
