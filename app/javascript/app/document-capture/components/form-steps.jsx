import React, { useEffect, useState } from 'react';
import PropTypes from 'prop-types';
import Button from './button';
import useI18n from '../hooks/use-i18n';
import useHistoryParam from '../hooks/use-history-param';

/**
 * @typedef FormStep
 *
 * @prop {string}                    name      Step name, used in history parameter.
 * @prop {import('react').Component} component Step component implementation.
 * @prop {(values:object)=>boolean}  isValid   Step validity function. Given set of form values,
 *                                             returns true if values satisfy requirements.
 */

/**
 * Given a step object and current set of form values, returns true if the form values would satisfy
 * the validity requirements of the step.
 *
 * @param {FormStep} step   Form step.
 * @param {object}   values Current form values.
 */
export function isStepValid(step, values) {
  const { isValid = () => true } = step;
  return isValid(values);
}

/**
 * Hook which ensures that given the current set of steps and form values, the current step state is
 * valid per the requirements of the step. At mount, if any step is not satisfied by the current
 * form values, the current step will be set to that step.
 *
 * @param {FormStep[]}              steps       Form steps.
 * @param {object}                  values      Form values.
 * @param {FormStep|undefined}      currentStep Current step, if known.
 * @param {(nextStep:string)=>void} setStepName Step setter.
 */
function useVerifiedCompletion(steps, values, currentStep, setStepName) {
  useEffect(() => {
    if (!currentStep) {
      return;
    }

    for (let i = 0; i < steps.length; i += 1) {
      const step = steps[i];
      if (step.name === currentStep.name) {
        break;
      }

      if (!isStepValid(step, values)) {
        setStepName(step.name);
        break;
      }
    }
  }, []);
}

function FormSteps({ steps, onComplete }) {
  const [values, setValues] = useState({});
  const [stepName, setStepName] = useHistoryParam('step');
  const t = useI18n();

  const stepIndex = stepName ? steps.findIndex((_step) => _step.name === stepName) : 0;
  const step = steps[stepIndex];
  useVerifiedCompletion(steps, values, step, setStepName);

  // An empty steps array is allowed, in which case there is nothing to render.
  if (!step) {
    return null;
  }

  /**
   * Increments state to the next step, or calls onComplete callback if the current step is the last
   * step.
   */
  function toNextStep() {
    const nextStepIndex = stepIndex + 1;
    const isComplete = nextStepIndex === steps.length;
    if (isComplete) {
      // Clear step parameter from URL.
      setStepName(null);
      onComplete(values);
    } else {
      const { name: nextStepName } = steps[nextStepIndex];
      setStepName(nextStepName);
    }
  }

  const { component: Component, name } = step;
  const isLastStep = stepIndex + 1 === steps.length;

  return (
    <>
      <Component
        key={name}
        value={values}
        onChange={(nextValuesPatch) => setValues({ ...values, ...nextValuesPatch })}
      />
      <Button isPrimary onClick={toNextStep} isDisabled={!isStepValid(step, values)}>
        {t(isLastStep ? 'forms.buttons.submit.default' : 'forms.buttons.continue')}
      </Button>
    </>
  );
}

FormSteps.propTypes = {
  steps: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string.isRequired,
      component: PropTypes.elementType.isRequired,
      isValid: PropTypes.func,
    }),
  ),
  onComplete: PropTypes.func,
};

FormSteps.defaultProps = {
  steps: [],
  onComplete: () => {},
};

export default FormSteps;
