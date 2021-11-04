import { useI18n } from '@18f/identity-react-i18n';
import { TroubleshootingOptions } from '@18f/identity-components';
import useAsset from '../hooks/use-asset';
import PageHeading from './page-heading';

/** @typedef {import('@18f/identity-components/troubleshooting-options').TroubleshootingOption} TroubleshootingOption */

/**
 * @typedef WarningProps
 *
 * @prop {string=} heading Heading text.
 * @prop {string=} actionText Primary action button text.
 * @prop {(() => void)=} actionOnClick Primary action button text.
 * @prop {import('react').ReactNode} children Component children.
 * @prop {string=} troubleshootingHeading Heading text preceding troubleshooting options.
 * @prop {(TroubleshootingOption[])=} troubleshootingOptions Array of troubleshooting options.
 */

/**
 * @param {WarningProps} props
 */
function Warning({
  heading,
  actionText,
  actionOnClick,
  children,
  troubleshootingHeading,
  troubleshootingOptions,
}) {
  const { t } = useI18n();
  const { getAssetPath } = useAsset();

  return (
    <>
      <img
        alt=""
        src={getAssetPath('alert/warning-lg.svg')}
        width={54}
        height={54}
        className="display-block margin-bottom-4"
      />
      <PageHeading>{heading}</PageHeading>
      {children}
      {actionText && actionOnClick && (
        <div className="margin-y-5">
          <button
            type="button"
            className="usa-button usa-button--big usa-button--wide"
            onClick={actionOnClick}
          >
            {actionText}
          </button>
        </div>
      )}
      {troubleshootingOptions && (
        <TroubleshootingOptions
          heading={troubleshootingHeading || t('idv.troubleshooting.headings.having_trouble')}
          options={troubleshootingOptions}
        />
      )}
    </>
  );
}

export default Warning;
