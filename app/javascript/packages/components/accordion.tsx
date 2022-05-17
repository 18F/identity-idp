import { useRef } from 'react';
import type { ReactNode } from 'react';
import { useInstanceId } from '@18f/identity-react-hooks';

interface AccordionProps {
  header: string;

  children: ReactNode;
}

function Accordion({ header, children }: AccordionProps) {
  const uniqueId = useInstanceId();
  const ref = useRef(null as HTMLDivElement | null);

  return (
    <div ref={ref}>
      <div className="usa-accordion usa-accordion--bordered">
        <div className="usa-accordion__heading">
          <button
            type="button"
            className="usa-accordion__button"
            aria-expanded="false"
            aria-controls={`accordion-${uniqueId}`}
          >
            {header}
          </button>
        </div>
        <div id={`accordion-${uniqueId}`} className="usa-accordion__content usa-prose" hidden>
          {children}
        </div>
      </div>
    </div>
  );
}

export default Accordion;
