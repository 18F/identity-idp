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
  const classes = ['block-link', 'usa-link', 'width-full', className].filter(Boolean).join(' ');

  return (
    <Button type="submit" {...linkProps} className={classes} isUnstyled>
      {children}
      <BlockLinkArrow />
    </Button>
  );
}

export default BlockSubmitButton;
