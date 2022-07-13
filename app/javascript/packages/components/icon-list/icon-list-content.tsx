import type { ReactNode } from 'react';

interface IconListContentProps {
  children?: ReactNode;
}

function IconListContent({ children }: IconListContentProps) {
  const classes = 'usa-icon-list__content';

  return <div className={classes}>{children}</div>;
}

export default IconListContent;
