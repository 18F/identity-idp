import type { ReactNode } from 'react';

interface IconListProps {
  children?: ReactNode;
}

function IconList({ children }: IconListProps) {
  const classes = 'usa-icon-list';

  return <ul className={classes}>{children}</ul>;
}

export default IconList;
