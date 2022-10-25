import type { ReactNode, HTMLAttributes } from 'react';

interface TagProps extends HTMLAttributes<HTMLElement> {
  /**
   * Element children.
   */
  children?: ReactNode;
}

function Tag({ children, className, ...props }: TagProps) {
  const classes = ['usa-tag', className].filter(Boolean).join(' ');

  return (
    <span {...props} className={classes}>
      {children}
    </span>
  );
}

export default Tag;
