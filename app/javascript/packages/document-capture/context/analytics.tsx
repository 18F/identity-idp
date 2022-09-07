import { createContext, useState } from 'react';
import type { ReactChild } from 'react';
import type { trackEvent } from '@18f/identity-analytics';

type SetSubmitEventMetadata = (metadata: Record<string, any>) => void;

type TrackSubmitEvent = (stepName: string) => void;

type TrackVisitEvent = (stepName: string) => void;

interface AnalyticsContextValue {
  /**
   * Log an action with optional payload.
   */
  trackEvent: typeof trackEvent;

  /**
   * Callback to trigger logging when a step is submitted.
   */
  trackSubmitEvent: TrackSubmitEvent;

  /**
   * Callback to trigger logging when a step is visited.
   */
  trackVisitEvent: TrackVisitEvent;

  /**
   * Sets additional metadata to be included in the next tracked submit event.
   */
  setSubmitEventMetadata: SetSubmitEventMetadata;
}

type AnalyticsContextProviderProps = Pick<AnalyticsContextValue, 'trackEvent'> & {
  children: ReactChild;
};

const DEFAULT_EVENT_METADATA: Record<string, any> = {};

const LOGGED_STEPS: string[] = ['location', 'prepare', 'switch_back'];

const AnalyticsContext = createContext<AnalyticsContextValue>({
  trackEvent: () => Promise.resolve(),
  trackSubmitEvent() {},
  trackVisitEvent() {},
  setSubmitEventMetadata() {},
});

AnalyticsContext.displayName = 'AnalyticsContext';

export function AnalyticsContextProvider({ children, trackEvent }: AnalyticsContextProviderProps) {
  const [submitEventMetadata, setSubmitEventMetadataState] = useState(DEFAULT_EVENT_METADATA);
  const setSubmitEventMetadata: SetSubmitEventMetadata = (metadata) =>
    setSubmitEventMetadataState((prevState) => ({ ...prevState, ...metadata }));
  const trackSubmitEvent: TrackSubmitEvent = (stepName) => {
    if (LOGGED_STEPS.includes(stepName)) {
      trackEvent(`IdV: ${stepName} submitted`, submitEventMetadata);
    }

    setSubmitEventMetadataState(DEFAULT_EVENT_METADATA);
  };
  const trackVisitEvent: TrackVisitEvent = (stepName) => {
    if (LOGGED_STEPS.includes(stepName)) {
      trackEvent(`IdV: ${stepName} visited`);
    }
  };

  const value = { trackEvent, trackVisitEvent, trackSubmitEvent, setSubmitEventMetadata };

  return <AnalyticsContext.Provider value={value}>{children}</AnalyticsContext.Provider>;
}

export default AnalyticsContext;
