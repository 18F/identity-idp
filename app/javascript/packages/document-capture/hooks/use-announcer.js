import { createContext, createRef, useContext, useState, useEffect } from 'react';

const AnnouncerInstancesContext = createContext(
  /** @type {import('react').MutableRefObject<[count: number, container: HTMLElement]>} */ (createRef()),
);

function useAnnouncer() {
  const [announcement, setAnnouncement] = useState('');
  const context = useContext(AnnouncerInstancesContext);

  useEffect(() => {
    if (!context.current || !context.current[0]) {
      const container = document.createElement('div');
      container.classList.add('usa-sr-only');
      container.setAttribute('aria-live', 'polite');
      document.body.appendChild(container);
      context.current = [0, container];
    }

    context.current[0]++;
    return () => {
      if (!--context.current[0]) {
        const [, container] = context.current;
        document.body.removeChild(container);
      }
    };
  }, []);

  useEffect(() => {
    context.current[1].textContent = announcement;
  }, [announcement]);

  return setAnnouncement;
}

export default useAnnouncer;
