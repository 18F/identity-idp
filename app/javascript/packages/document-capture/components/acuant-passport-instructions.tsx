import { getAssetPath } from '@18f/identity-assets';
import { t } from '@18f/identity-i18n';

export default function AcuantPassportInstructions() {
  return (
    <>
      <div className="margin-bottom-1 text-bold">
        {t('doc_auth.headings.passport_instructions.howto')}
      </div>
      <div className="display-flex">
        <img
          src={getAssetPath('idv/passport-capture-help.svg')}
          alt={t('doc_auth.alt.passport_help')}
        />
        <div>
          <div className="margin-left-2 margin-bottom-2">
            {t('doc_auth.info.passport_capture_help_1')}
          </div>
          <div className="margin-left-2">{t('doc_auth.info.passport_capture_help_2')}</div>
        </div>
      </div>
    </>
  );
}
