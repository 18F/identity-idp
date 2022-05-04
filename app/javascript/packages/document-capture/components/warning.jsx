import { useContext, useEffect } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { PageHeading } from '@18f/identity-components';
import { getAssetPath } from '@18f/identity-assets';
import AnalyticsContext from '../context/analytics';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef WarningProps
 *
 * @prop {string=} heading Heading text.
 * @prop {string=} actionText Primary action button text.
 * @prop {(() => void)=} actionOnClick Primary action button text.
 * @prop {import('react').ReactNode} children Component children.
 * @prop {ReactNode=} troubleshootingOptions Troubleshooting options.
 * @prop {string} location Source component mounting warning.
 * @prop {number=} remainingAttempts The number of attempts the user can make.
 */

/**
 * @param {WarningProps} props
 */
function Warning({
  heading,
  actionText,
  actionOnClick,
  children,
  troubleshootingOptions,
  location,
  remainingAttempts,
}) {
  const { addPageAction } = useContext(AnalyticsContext);
  const { t } = useI18n();
  useEffect(() => {
    addPageAction('IdV: warning shown', { location, remaining_attempts: remainingAttempts });
  }, []);

  return (
    <>
      <img
        alt={t('errors.alt.warning')}
        src={getAssetPath('status/warning.svg')}
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
            onClick={() => {
              addPageAction('IdV: warning action triggered', { location });
              actionOnClick();
            }}
          >
            {actionText}
          </button>
        </div>
      )}
      {troubleshootingOptions}
    </>
  );
}

export default Warning;
