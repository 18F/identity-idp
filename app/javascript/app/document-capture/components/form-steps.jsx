import React, { useState } from 'react';
import PropTypes from 'prop-types';
import Button from './button';
import useI18n from '../hooks/use-i18n';
import useHistoryParam from '../hooks/use-history-param';

function FormSteps({ steps, onComplete }) {
  const [values, setValues] = useState({});
  const [stepName, setStepName] = useHistoryParam('step');
  const t = useI18n();

  const stepIndex = stepName ? steps.findIndex((_step) => _step.name === stepName) : 0;
  const step = steps[stepIndex];

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
  /** @type {{isValid:(values:object)=>boolean}} */
  const { isValid = () => true } = Component;
  const isLastStep = stepIndex + 1 === steps.length;

  return (
    <>
      <Component
        key={name}
        value={values}
        onChange={(nextValuesPatch) => setValues({ ...values, ...nextValuesPatch })}
      />
      <Button isPrimary onClick={toNextStep} isDisabled={!isValid(values)}>
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
