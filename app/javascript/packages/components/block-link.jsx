import { useI18n } from '@18f/identity-react-i18n';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef BlockLinkProps
 *
 * @prop {string} url Link destination.
 * @prop {boolean=} isNewTab Whether link should open in a new tab. Defaults to false. Use best
 * judgment to reserve new tabs to when absolutely necessary, such as when form data may otherwise
 * be lost.
 * @prop {ReactNode} children Child elements.
 */

/**
 * @param {BlockLinkProps} props
 */
function BlockLink({ url, children, isNewTab = false }) {
  const { t } = useI18n();

  const classes = ['usa-link', 'block-link', isNewTab && 'usa-link--external']
    .filter(Boolean)
    .join(' ');

  let newTabProps;
  if (isNewTab) {
    newTabProps = { target: '_blank', rel: 'noreferrer' };
  }

  return (
    <a href={url} className={classes} {...newTabProps}>
      {children}
      {isNewTab && <span className="usa-sr-only"> {t('links.new_window')}</span>}
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 5.2 8.91"
        focusable="false"
        aria-hidden="true"
        className="block-link__arrow"
      >
        <path
          d="M5.11 4.66L1 8.82a.36.36 0 01-.21.09.31.31 0 01-.2-.09l-.5-.45a.29.29 0 01-.09-.2A.36.36 0 01.09 8L3.6 4.45.09 1A.36.36 0 010 .74a.31.31 0 01.09-.2L.54.09A.31.31 0 01.74 0 .36.36 0 011 .09l4.11 4.16a.31.31 0 01.09.2.31.31 0 01-.09.21z"
          fill="currentColor"
        />
      </svg>
    </a>
  );
}

export default BlockLink;
