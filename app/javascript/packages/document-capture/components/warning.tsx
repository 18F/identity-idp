import { useContext, useEffect } from 'react';
import type { ReactNode, ReactComponentElement } from 'react';
import { StatusPage, Button } from '@18f/identity-components';
import type { TroubleshootingOptions } from '@18f/identity-components';
import AnalyticsContext from '../context/analytics';

interface WarningProps {
  /**
   * Heading text.
   */
  heading: string;

  /**
   * Primary action button text.
   */
  actionText?: string;

  /**
   * Primary action button text.
   */
  actionOnClick?: () => void;

  /**
   * Secondary action button text.
   */
  altActionText?: string;

  /**
   * Secondary action button text.
   */
  altActionOnClick?: () => void;

  /**
   * Secondary action button location.
   */
  altHref?: string;

  /**
   * Component children.
   */
  children: ReactNode;

  /**
   * Troubleshooting options.
   */
  troubleshootingOptions?: ReactComponentElement<typeof TroubleshootingOptions>;

  /**
   * Source component mounting warning.
   */
  location: string;

  /**
   * The number of attempts the user can make.
   */
  remainingAttempts?: number;

  /**
   * The error message displayed to the user after submitting photos that cannot be used for doc auth.
   */
  errorMessageDisplayed: string;
}

function Warning({
  heading,
  actionText,
  actionOnClick,
  altActionText,
  altActionOnClick,
  altHref,
  children,
  troubleshootingOptions,
  location,
  remainingAttempts,
  errorMessageDisplayed,
}: WarningProps) {
  const { trackEvent } = useContext(AnalyticsContext);
  useEffect(() => {
    trackEvent('IdV: warning shown', {
      location,
      remaining_attempts: remainingAttempts,
      heading,
      errorMessageDisplayed,
    });
  }, []);

  let actionButtons: ReactComponentElement<typeof Button>[] | undefined;
  if (actionText && actionOnClick) {
    actionButtons = [
      <Button
        isBig
        isWide
        onClick={() => {
          trackEvent('IdV: warning action triggered', { location });
          actionOnClick();
        }}
      >
        {actionText}
      </Button>,
    ];
    if (altActionText && altActionOnClick) {
      actionButtons.push(
        <Button
          isBig
          isOutline
          isWide
          href={altHref}
          onClick={() => {
            trackEvent('IdV: warning action triggered', { location });
            altActionOnClick();
          }}
        >
          {altActionText}
        </Button>,
      );
    }
  }

  return (
    <StatusPage
      header={heading}
      status="warning"
      actionButtons={actionButtons}
      troubleshootingOptions={troubleshootingOptions}
    >
      {children}
    </StatusPage>
  );
}

export default Warning;
