import type { ReactNode } from 'react';

interface LocationCollectionProps {
  className?: string;

  children?: ReactNode;
}

function LocationCollection({ children, className }: LocationCollectionProps) {
  // need to update this to use correct classname
  const classes = ['usa-collection', className].filter(Boolean).join(' ');

  return <ul className={classes}>{children}</ul>;
}

export default LocationCollection;
