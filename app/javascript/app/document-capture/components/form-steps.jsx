import React, { useState } from 'react';
import PropTypes from 'prop-types';
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

  function setStepValue(name, nextStepValue) {
    setValues({ ...values, [name]: nextStepValue });
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
        value={values[name]}
        onChange={(nextStepValue) => setStepValue(name, nextStepValue)}
      />
      <button type="button" onClick={toNextStep}>
        {t(isLastStep ? 'forms.buttons.submit.default' : 'forms.buttons.continue')}
      </button>
    </>
  );
}

FormSteps.propTypes = {
  steps: PropTypes.arrayOf(
    PropTypes.shape({
      name: PropTypes.string,
      component: PropTypes.elementType,
    }),
  ),
  onComplete: PropTypes.func,
};

FormSteps.defaultProps = {
  steps: [],
  onComplete: () => {},
};

export default FormSteps;
