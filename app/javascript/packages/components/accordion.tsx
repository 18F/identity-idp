import { useRef, useEffect } from 'react';
import type { ReactNode } from 'react';
import { accordion } from 'identity-style-guide';
import { useInstanceId } from '@18f/identity-react-hooks';

interface AccordionProps {
  header: string;

  children: ReactNode;
}

function Accordion({ header, children }: AccordionProps) {
  const uniqueId = useInstanceId();
  const ref = useRef(null as HTMLDivElement | null);
  // This  does not work it will force it to hidden over and over.
  // useEffect(() => {
  //   accordion.on(ref.current!);
  // }, []);

  return (
    <div ref={ref}>
      <div className="usa-accordion">
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
          <div className="usa-accordion__content usa-prose">{children}</div>
        </div>
      </div>
    </div>
  );
}

export default Accordion;
