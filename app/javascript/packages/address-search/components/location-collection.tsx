import type { LocationCollectionProps } from '../types';

function LocationCollection({ children, className }: LocationCollectionProps) {
  const classes = ['usa-collection', className].filter(Boolean).join(' ');
  return <ul className={classes}>{children}</ul>;
}

export default LocationCollection;
