import { useRef, useEffect } from 'react';
import type { ReactNode } from 'react';

interface ScrollIntoViewProps {
  children: ReactNode;
}

/**
 * Scrolls content into the user's viewport when mounted.
 */
function ScrollIntoView({ children }: ScrollIntoViewProps) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => ref.current?.scrollIntoView(), []);

  return <div ref={ref}>{children}</div>;
}

export default ScrollIntoView;
