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
 * Returns the index of the step in the array which matches the given name. Returns `-1` if there is
 * no step found by that name.
 *
 * @param {FormStep[]} steps Form steps.
 * @param {string}     name  Step to search.
 *
 * @return {number} Step index.
 */
export function getStepIndexByName(steps, name) {
  return steps.findIndex((step) => step.name === name);
}

/**
 * Returns the index of the last step in the array where the values satisfy the requirements of the
 * step. If all steps are valid, returns the index of the last member. Returns `-1` if all steps are
 * invalid, or if the array is empty.
 *
 * @param {FormStep[]} steps  Form steps.
 * @param {object}     values Current form values.
 *
 * @return {number} Step index.
 */
export function getLastValidStepIndex(steps, values) {
  const index = steps.findIndex((step) => !isStepValid(step, values));
  return index === -1 ? steps.length - 1 : index - 1;
}

function FormSteps({ steps, onComplete }) {
  const [values, setValues] = useState({});
  const [stepName, setStepName] = useHistoryParam('step');
  const { t } = useI18n();

  // An "effective" step is computed in consideration of the facts that (1) there may be no history
  // parameter present, in which case the first step should be used, and (2) the values may not be
  // valid for previous steps, in which case the furthest valid step should be set.
  const effectiveStepIndex = Math.max(
    Math.min(getStepIndexByName(steps, stepName), getLastValidStepIndex(steps, values) + 1),
    0,
  );
  const effectiveStep = steps[effectiveStepIndex];
  useEffect(() => {
    // The effective step is used in the initial render, but since it may be out of sync with the
    // history parameter, it is synced after mount.
    if (effectiveStep && stepName && effectiveStep.name !== stepName) {
      setStepName(effectiveStep.name);
    }
  }, []);

  // An empty steps array is allowed, in which case there is nothing to render.
  if (!effectiveStep) {
    return null;
  }

  /**
   * Increments state to the next step, or calls onComplete callback if the current step is the last
   * step.
   */
  function toNextStep() {
    const nextStepIndex = effectiveStepIndex + 1;
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

  const { component: Component, name } = effectiveStep;
  const isLastStep = effectiveStepIndex + 1 === steps.length;

  return (
    <>
      <Component
        key={name}
        value={values}
        onChange={(nextValuesPatch) => {
          setValues((prevValues) => ({ ...prevValues, ...nextValuesPatch }));
        }}
      />
      <Button
        isPrimary
        onClick={toNextStep}
        isDisabled={!isStepValid(effectiveStep, values)}
        className="margin-y-5"
      >
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
