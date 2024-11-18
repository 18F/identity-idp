import { getAssetPath } from '@18f/identity-assets';
import { t } from '@18f/identity-i18n';

export default function AcuantSelfieInstructions() {
  return (
    <>
      <div className="margin-bottom-1 text-bold">{t('doc_auth.headings.selfie_instructions.howto')}</div>
      <div className="display-flex">
        <img src={getAssetPath('idv/selfie-capture-help.svg')} alt={t('doc_auth.alt.selfie_help_1')} />
        <div className="margin-left-2">{t('doc_auth.info.selfie_capture_help_1')}</div>
      </div>
      <div className="display-flex margin-top-1">
        <img src={getAssetPath('idv/selfie-capture-accept-help.svg')} alt={t('doc_auth.alt.selfie_help_2')} />
        <div className="margin-left-2">{t('doc_auth.info.selfie_capture_help_2')}</div>
      </div>
    </>
  );
}
