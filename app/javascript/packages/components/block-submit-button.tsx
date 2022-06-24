import type { ReactNode } from 'react';
import { Button, ButtonProps } from '@18f/identity-components';
import BlockLinkArrow from './block-link-arrow';

interface BlockSubmitButtonProps extends ButtonProps {
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
