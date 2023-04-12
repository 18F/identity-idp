import { useI18n } from '@18f/identity-react-i18n';
import { getAssetPath } from '@18f/identity-assets';
import Warning from './warning';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';

/** @typedef {import('@18f/identity-components/troubleshooting-options').TroubleshootingOption} TroubleshootingOption */

/**
 * @typedef CaptureAdviceProps
 *
 * @prop {() => void} onTryAgain
 * @prop {boolean} isAssessedAsGlare
 * @prop {boolean} isAssessedAsBlurry
 */

/**
 * @param {CaptureAdviceProps} props
 */
function CaptureAdvice({ onTryAgain, isAssessedAsGlare, isAssessedAsBlurry }) {
  const { t } = useI18n();

  return (
    <Warning
      heading={t('doc_auth.headings.capture_troubleshooting_tips')}
      actionText={t('idv.failure.button.warning')}
      actionOnClick={onTryAgain}
      location="doc_auth_capture_advice"
      troubleshootingOptions={
        <DocumentCaptureTroubleshootingOptions
          heading={t('idv.troubleshooting.headings.still_having_trouble')}
          location="capture_tips"
          showAlternativeProofingOptions
        />
      }
    >
      <p>
        {isAssessedAsGlare && t('doc_auth.tips.capture_troubleshooting_glare')}
        {isAssessedAsBlurry && t('doc_auth.tips.capture_troubleshooting_blurry')}{' '}
        {t('doc_auth.tips.capture_troubleshooting_lead')}
      </p>
      <ul className="add-list-reset margin-y-3">
        <li className="clearfix margin-bottom-3">
          <img
            width="82"
            height="82"
            src={getAssetPath('idv/capture-tips-surface.svg')}
            alt={t('doc_auth.tips.capture_troubleshooting_surface_image')}
            className="float-left margin-right-2"
          />
          {t('doc_auth.tips.capture_troubleshooting_surface')}
        </li>
        <li className="clearfix margin-bottom-3">
          <img
            width="82"
            height="82"
            src={getAssetPath('idv/capture-tips-lighting.svg')}
            alt={t('doc_auth.tips.capture_troubleshooting_lighting_image')}
            className="float-left margin-right-2"
          />
          {t('doc_auth.tips.capture_troubleshooting_lighting')}
        </li>
        <li className="clearfix">
          <img
            width="82"
            height="82"
            src={getAssetPath('idv/capture-tips-clean.svg')}
            alt={t('doc_auth.tips.capture_troubleshooting_clean_image')}
            className="float-left margin-right-2"
          />
          {t('doc_auth.tips.capture_troubleshooting_clean')}
        </li>
      </ul>
    </Warning>
  );
}

export default CaptureAdvice;
