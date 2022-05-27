import { useMemo } from 'react';
import type { Dispatch } from 'react';
import { FormStep, getStepParam } from '@18f/identity-form-steps';
import useSessionStorage from './use-session-storage';

/**
 * Returns the index of the given step name in the form steps order.
 *
 * @param stepName Step name.
 * @param steps Steps order.
 *
 * @return Step index.
 */
const getStepIndex = (stepName: string, steps: FormStep[]) =>
  steps.findIndex((step) => step.name === stepName);

/**
 * React hook which validates the expected initial step to present the user, based on past
 * completion and presence of a URL path fragment. Behaves similar to a useState hook, where the
 * return value is a tuple of the validated initial step, and a setter for assigning a completed
 * step.
 *
 * @param basePath Path to which the current step is appended to create the current step URL.
 * @param steps Steps order.
 *
 * @return Tuple of the validated initial step and a setter for assigning a completed step.
 */
function useInitialStepValidation(
  basePath: string,
  steps: FormStep[],
): [string, Dispatch<string | null>] {
  const [completedStep, setCompletedStep] = useSessionStorage('completedStep');
  const initialStep = useMemo(() => {
    const pathStep = getStepParam(window.location.pathname.split(basePath)[1]);
    const completedStepIndex = completedStep ? getStepIndex(completedStep, steps) : -1;
    const pathStepIndex = getStepIndex(pathStep, steps);
    const firstStepIndex = 0;
    const stepIndex = Math.max(Math.min(completedStepIndex + 1, pathStepIndex), firstStepIndex);
    return steps[stepIndex].name;
  }, []);

  return [initialStep, setCompletedStep];
}

export default useInitialStepValidation;
