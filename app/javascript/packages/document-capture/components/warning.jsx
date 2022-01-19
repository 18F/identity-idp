import { useContext, useEffect } from 'react';
import AnalyticsContext from '../context/analytics';
import useAsset from '../hooks/use-asset';
import PageHeading from './page-heading';

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
  const { getAssetPath } = useAsset();
  const { addPageAction } = useContext(AnalyticsContext);
  useEffect(() => {
    const payload = { location };
    if (remainingAttempts) {
      payload.remaining_step_attempts = remainingAttempts;
    }
    addPageAction({
      label: 'IdV: warning shown',
      payload: payload,
    });
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
              addPageAction({ label: 'IdV: warning action triggered', payload: { location } });
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
