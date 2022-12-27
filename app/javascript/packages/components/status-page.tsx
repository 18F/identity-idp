import type { ReactNode, ReactComponentElement } from 'react';
import { getAssetPath } from '@18f/identity-assets';
import { t } from '@18f/identity-i18n';
import PageHeading from './page-heading';
import Button from './button';
import TroubleshootingOptions from './troubleshooting-options';

/**
 * Status to be communicated to the user.
 */
type Status = 'info' | 'warning' | 'error';

/**
 * Icon variations for statuses.
 */
type Icon = 'question' | 'lock';

/**
 * Asset paths for combination of status, icon.
 */
const STATUS_ICONS: Record<Status, Record<Icon & 'default', string>> = {
  info: {
    question: getAssetPath('status/info-question.svg'),
  },
  warning: {
    default: getAssetPath('status/warning.svg'),
  },
  error: {
    default: getAssetPath('status/error.svg'),
    lock: getAssetPath('status/error-lock.svg'),
  },
};

/**
 * Text to be used as text alternative for icon.
 */
const STATUS_ALT: Record<Status & Icon, string> = {
  error: t('image_description.error'),
  question: t('image_description.info_question'),
  warning: t('image_description.warning'),
  lock: t('image_description.error_lock'),
};

interface StatusPageProps {
  /**
   * Status to be communicated to the user.
   */
  status: Status;

  /**
   * Icon variation.
   */
  icon?: Icon;

  /**
   * Header text.
   */
  header: string;

  /**
   * Body content of status page.
   */
  children?: ReactNode;

  /**
   * Optional action buttons, shown below body content.
   */
  actionButtons?: ReactComponentElement<typeof Button>[];

  /**
   * Optional troubleshooting options, shown below action buttons.
   */
  troubleshootingOptions?: ReactComponentElement<typeof TroubleshootingOptions>;
}

function StatusPage({
  status,
  icon,
  header,
  children,
  actionButtons = [],
  troubleshootingOptions,
}: StatusPageProps) {
  const src = STATUS_ICONS[status][icon || 'default'];
  const alt = STATUS_ALT[icon || status];

  return (
    <>
      <img
        src={src}
        alt={alt}
        width={88}
        height={88}
        className="display-block margin-bottom-4 alert-icon"
      />
      <PageHeading>{header}</PageHeading>
      {children}
      {actionButtons.length > 0 && (
        <div className="margin-top-5">
          {actionButtons.map((actionButton, index) => (
            <div key={index} className="margin-top-2">
              {actionButton}
            </div>
          ))}
        </div>
      )}
      {troubleshootingOptions && <div className="margin-top-5">{troubleshootingOptions}</div>}
    </>
  );
}

export default StatusPage;
