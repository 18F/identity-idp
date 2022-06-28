import type { ReactNode } from 'react';
import BlockLinkArrow from './block-link-arrow';

interface BlockSubmitButtonProps extends React.ComponentPropsWithoutRef<"button"> {
  /**
   * Link text.
   */
  children?: ReactNode;

  /**
   * Additional class names to apply.
   */
  className?: string;
}

function BlockSubmitButton({ children, className, ...linkProps }: BlockSubmitButtonProps) {
  const classes = ['button-link', 'width-full', className].filter(Boolean).join(' ');

  return (
    <button type="submit" {...linkProps} className={classes}>
      {children}
      <BlockLinkArrow />
    </button>
  );
}

export default BlockSubmitButton;
