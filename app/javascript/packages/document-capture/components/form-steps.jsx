import React, { useEffect, useRef, useState } from 'react';
import Button from './button';
import PageHeading from './page-heading';
import useI18n from '../hooks/use-i18n';
import useHistoryParam from '../hooks/use-history-param';

/**
 * @typedef FormStep
 *
 * @prop {string}                            name      Step name, used in history parameter.
 * @prop {string}                            title     Step title, shown as heading.
 * @prop {import('react').FunctionComponent} component Step component implementation.
 * @prop {(values:object)=>boolean=}         isValid   Step validity function. Given set of form
 *                                                     values, returns true if values satisfy
 *                                                     requirements.
 */

/**
 * @typedef FormStepsProps
 *
 * @prop {FormStep[]=}                        steps      Form steps.
 * @prop {(values:Record<string,any>)=>void=} onComplete Form completion callback.
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

/**
 * @param {FormStepsProps} props Props object.
 */
function FormSteps({ steps = [], onComplete = () => {} }) {
  const [values, setValues] = useState({});
  const formRef = useRef(/** @type {?HTMLFormElement} */ (null));
  const headingRef = useRef(/** @type {?HTMLHeadingElement} */ (null));
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
   *
   * @type {import('react').FormEventHandler}
   */
  function toNextStep(event) {
    event.preventDefault();

    // It shouldn't be necessary to perform validation of the step at this point, since the spec
    // guarantees us that submission will occur as a click on the button, which will be suppressed
    // by the presence of the disabled attribute.
    //
    // "If the user agent supports letting the user submit a form implicitly (for example, on some
    // platforms hitting the "enter" key while a text control is focused implicitly submits the
    // form), then doing so for a form, whose default button has activation behavior and is not
    // disabled, must cause the user agent to fire a click event at that default button."
    //
    // See: https://html.spec.whatwg.org/multipage/form-control-infrastructure.html#implicit-submission
    //
    // Furthermore, even if the step was progressed, the logic of effective step computation would
    // avoid the next step being shown prematurely.

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

    headingRef.current.focus();
  }

  const { component: Component, name, title } = effectiveStep;
  const isLastStep = effectiveStepIndex + 1 === steps.length;

  return (
    <form ref={formRef} onSubmit={toNextStep}>
      <PageHeading key="title" ref={headingRef} tabIndex={-1}>
        {title}
      </PageHeading>
      <Component
        key={name}
        value={values}
        onChange={(nextValuesPatch) => {
          setValues((prevValues) => ({ ...prevValues, ...nextValuesPatch }));
        }}
      />
      <Button
        type="submit"
        isPrimary
        isDisabled={!isStepValid(effectiveStep, values)}
        className="margin-y-5"
      >
        {t(isLastStep ? 'forms.buttons.submit.default' : 'forms.buttons.continue')}
      </Button>
    </form>
  );
}

export default FormSteps;
