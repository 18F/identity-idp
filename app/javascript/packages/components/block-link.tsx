import Link, { LinkProps } from './link';

export interface BlockLinkProps extends LinkProps {
  /**
   * Link destination.
   */
  href: string;
}

function BlockLink({ href, children, className, ...linkProps }: BlockLinkProps) {
  const classes = ['block-link', className].filter(Boolean).join(' ');

  return (
    <Link href={href} {...linkProps} className={classes}>
      {children}
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
    </Link>
  );
}

export default BlockLink;
