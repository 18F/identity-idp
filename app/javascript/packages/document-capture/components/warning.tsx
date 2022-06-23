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
}

function Warning({
  heading,
  actionText,
  actionOnClick,
  children,
  troubleshootingOptions,
  location,
  remainingAttempts,
}: WarningProps) {
  const { addPageAction } = useContext(AnalyticsContext);
  useEffect(() => {
    addPageAction('IdV: warning shown', { location, remaining_attempts: remainingAttempts });
  }, []);

  let actionButtons: ReactComponentElement<typeof Button>[] | undefined;
  if (actionText && actionOnClick) {
    actionButtons = [
      <Button
        isBig
        isWide
        onClick={() => {
          addPageAction('IdV: warning action triggered', { location });
          actionOnClick();
        }}
      >
        {actionText}
      </Button>,
    ];
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
