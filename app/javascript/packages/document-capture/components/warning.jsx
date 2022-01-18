import useAsset from '../hooks/use-asset';
import PageHeading from './page-heading';
import { useEffect } from 'react';
import { trackEvent } from '@18f/identity-analytics';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef WarningProps
 *
 * @prop {string=} heading Heading text.
 * @prop {string=} actionText Primary action button text.
 * @prop {(() => void)=} actionOnClick Primary action button text.
 * @prop {import('react').ReactNode} children Component children.
 * @prop {ReactNode=} troubleshootingOptions Troubleshooting options.
 * @prop {string=} location Source component mounting warning.
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
}) {
  const { getAssetPath } = useAsset();
  useEffect(() => {
    trackEvent('IdV: warning visited', { location });
  }, []);

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
            onClick={() => {
              trackEvent('IdV: warning action triggered', { location });
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
