import { useCallback, useContext, useEffect } from 'react';
import AnalyticsContext from '../context/analytics';
import InPersonLocationStep from '../components/in-person-location-step';
import InPersonPrepareStep from '../components/in-person-prepare-step';
import InPersonSwitchBackStep from '../components/in-person-switch-back-step';

export const LOGGED_STEPS: string[] = [
  InPersonLocationStep.stepName,
  InPersonPrepareStep.stepName,
  InPersonSwitchBackStep.stepName,
];

const isLoggedStep = (stepName?: string): boolean => !!stepName && LOGGED_STEPS.includes(stepName);

function useStepLogger(currentStep?: string) {
  const { trackEvent } = useContext(AnalyticsContext);
  const onStepSubmit = useCallback(
    (stepName?: string) => {
      if (isLoggedStep(stepName)) {
        trackEvent(`IdV: ${stepName} submitted`);
      }
    },
    [trackEvent],
  );
  useEffect(() => {
    if (isLoggedStep(currentStep)) {
      trackEvent(`IdV: ${currentStep} visited`);
    }
  }, [currentStep]);

  return { onStepSubmit };
}

export default useStepLogger;
