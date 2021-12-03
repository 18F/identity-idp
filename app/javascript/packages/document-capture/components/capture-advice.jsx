import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import ServiceProviderContext from '../context/service-provider';
import HelpCenterContext from '../context/help-center';
import useAsset from '../hooks/use-asset';
import Warning from './warning';

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
  const { name: spName, getFailureToProofURL } = useContext(ServiceProviderContext);
  const { getHelpCenterURL } = useContext(HelpCenterContext);
  const { getAssetPath } = useAsset();
  const { t } = useI18n();

  return (
    <Warning
      heading={t('doc_auth.headings.capture_troubleshooting_tips')}
      actionText={t('idv.failure.button.warning')}
      actionOnClick={onTryAgain}
      troubleshootingHeading={t('idv.troubleshooting.headings.still_having_trouble')}
      troubleshootingOptions={
        /** @type {TroubleshootingOption[]} */ ([
          {
            url: getHelpCenterURL({
              category: 'verify-your-identity',
              article: 'how-to-add-images-of-your-state-issued-id',
              location: 'capture_tips',
            }),
            text: t('idv.troubleshooting.options.doc_capture_tips'),
            isExternal: true,
          },
          spName && {
            url: getFailureToProofURL('capture_tips'),
            text: t('idv.troubleshooting.options.get_help_at_sp', { sp_name: spName }),
            isExternal: true,
          },
        ].filter(Boolean))
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
