import Link, { LinkProps } from './link';
import BlockLinkArrow from './block-link-arrow';

export interface BlockLinkProps extends LinkProps {}

function BlockLink({ children, className, ...linkProps }: BlockLinkProps) {
  const classes = ['block-link', className].filter(Boolean).join(' ');

  return (
    <Link {...linkProps} className={classes}>
      {children}
      <BlockLinkArrow />
    </Link>
  );
}

export default BlockLink;
