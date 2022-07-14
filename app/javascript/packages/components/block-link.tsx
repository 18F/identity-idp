import Link, { LinkProps } from './link';
import BlockLinkArrow from './block-link-arrow';

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
      <BlockLinkArrow />
    </Link>
  );
}

export default BlockLink;
