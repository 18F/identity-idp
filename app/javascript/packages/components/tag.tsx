import type { ReactNode, HTMLAttributes } from 'react';

interface TagProps extends HTMLAttributes<HTMLElement> {
  /**
   * Whether to render as the informative tag variant.
   */
  isInformative?: boolean;

  /**
   * Whether to render as the big tag variant.
   */
  isBig?: boolean;

  /**
   * Element children.
   */
  children?: ReactNode;
}

function Tag({ children, isInformative, isBig, className, ...props }: TagProps) {
  const classes = [
    'usa-tag',
    isInformative && 'usa-tag--informative',
    isBig && 'usa-tag--big',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <span {...props} className={classes}>
      {children}
    </span>
  );
}

export default Tag;
