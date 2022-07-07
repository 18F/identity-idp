import type { ReactNode } from 'react';

interface PageFooterProps {
  /**
   * Footer contents.
   */
  children: ReactNode;
}

function PageFooter({ children }: PageFooterProps) {
  return (
    <div className="margin-top-4 padding-top-2 border-top border-primary-light">{children}</div>
  );
}

export default PageFooter;
