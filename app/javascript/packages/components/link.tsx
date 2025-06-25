import type { ReactNode, AnchorHTMLAttributes } from 'react';
import { t } from '@18f/identity-i18n';

export interface LinkProps extends AnchorHTMLAttributes<HTMLAnchorElement> {
  /**
   * Link destination.
   */
  href: string;

  /**
   * Whether link destination is an external resource.
   */
  isExternal?: boolean;

  /**
   * Whether link should open in a new tab.
   */
  isNewTab?: boolean;

  /**
   * Additional class names to apply.
   */
  className?: string;

  /**
   * Link text.
   */
  children?: ReactNode;
}

export function isExternalURL(url, currentURL = window.location.href) {
  try {
    return new URL(url).hostname !== new URL(currentURL).hostname;
  } catch {
    return false;
  }
}

function Link({
  href,
  isExternal = isExternalURL(href),
  isNewTab = isExternal,
  className,
  children,
  ...anchorProps
}: LinkProps) {
  const classes = ['usa-link', className, isExternal && 'usa-link--external']
    .filter(Boolean)
    .join(' ');

  console.log('link href:', href);
  const handleClick = () => {
    // Clear the onbeforeunload event to prevent the "Leave site?" prompt
    if (href === '/verify/choose_id_type') {
      window.onbeforeunload = null;
    }
  };

  let newTabProps: AnchorHTMLAttributes<HTMLAnchorElement> | undefined;
  if (isNewTab) {
    newTabProps = { target: '_blank', rel: 'noreferrer' };
  }

  return (
    <a href={href} {...newTabProps} {...anchorProps} className={classes} onClick={handleClick}>
      {children}
      {isNewTab && <span className="usa-sr-only">{t('links.new_tab')}</span>}
    </a>
  );
}

export default Link;
