import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import useI18n from '../hooks/use-i18n';

function FormSteps({ steps, onComplete }) {
  const [values, setValues] = useState({});
  const [stepIndex, setStepIndex] = useState(0);
  const t = useI18n();

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
      window.history.pushState(null, null, window.location.pathname);

      onComplete(values);
    } else {
      const { name: nextStepName } = steps[nextStepIndex];

      // Push the next step to history, both to update the URL, and to allow the user to return to
      // an earlier step (see `popstate` sync behavior).
      window.history.pushState({ stepIndex: nextStepIndex }, nextStepName, `?step=${nextStepName}`);

      setStepIndex(nextStepIndex);
    }
  }

  useEffect(() => {
    function setStepIndexFromHistoryState(event) {
      // Since there is no history state at the initial step, use 0 as default.
      const { stepIndex: historyStepIndex = 0 } = event.state ?? {};
      setStepIndex(historyStepIndex);
    }

    // If URL contains a step parameter on initial mount, it won't be possible to salvage the state,
    // and the URL should be synced to the initial step state of the component (the first step).
    if (window.location.search) {
      window.history.replaceState(null, null, window.location.pathname);
    }

    window.addEventListener('popstate', setStepIndexFromHistoryState);
    return () => window.removeEventListener('popstate', setStepIndexFromHistoryState);
  }, []);

  const step = steps[stepIndex];

  // An empty steps array is allowed, in which case there is nothing to render.
  if (!step) {
    return null;
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
