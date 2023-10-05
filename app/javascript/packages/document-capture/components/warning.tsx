import { useContext } from 'react';
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
}: WarningProps) {
  const { trackEvent } = useContext(AnalyticsContext);

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
