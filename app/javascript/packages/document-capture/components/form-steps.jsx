import React, { useEffect, useRef, useState } from 'react';
import Button from './button';
import PageHeading from './page-heading';
import useI18n from '../hooks/use-i18n';
import useHistoryParam from '../hooks/use-history-param';

/**
 * @typedef FormStepError
 *
 * @prop {keyof V} field Name of field for which error occurred.
 * @prop {Error} error Error object.
 *
 * @template V
 */

/**
 * @typedef FormStepComponentProps
 *
 * @prop {(nextValues:Partial<V>)=>void} onChange Values change callback, merged with
 * existing values.
 * @prop {Partial<V>} value Current values.
 * @prop {FormStepError<V>[]=} errors Current active errors.
 * @prop {(field:string)=>undefined|((fieldNode:HTMLElement?)=>void)} registerField Registers field
 * by given name, returning ref assignment function.
 *
 * @template V
 */

/**
 * @template {Record<string,any>} V
 *
 * @typedef {FormStepError<V>[]} FormStepValidateResult
 */

/**
 * @template {Record<string,any>} V
 *
 * @typedef {(values:V)=>FormStepValidateResult<V>} FormStepValidate
 */

/**
 * @typedef FormStep
 *
 * @prop {string} name Step name, used in history parameter.
 * @prop {string} title Step title, shown as heading.
 * @prop {import('react').FC<FormStepComponentProps<Record<string,any>>>} component Step component.
 * @prop {FormStepValidate<Record<string,any>>} validate Step validity function. Given set of form
 * values, returns an object with keys from form values mapped to an error, if applicable. Returns
 * undefined or an empty object if there are no errors.
 * @prop {string[]=} fields Field names present in step.
 */

/**
 * @typedef FieldsRefEntry
 *
 * @prop {import('react').RefCallback<HTMLElement>} refCallback Ref callback.
 * @prop {HTMLElement?=} element Element assigned by ref callback.
 */

/**
 * @typedef FormStepsProps
 *
 * @prop {FormStep[]=} steps Form steps.
 * @prop {FormStepValidateResult<Record<string,Error>>=} initialActiveErrors Initial errors to show.
 * @prop {Record<string,any>=} initialValues Form values to populate initial state.
 * @prop {string=} initialStep Step to start from.
 * @prop {(values:Record<string,any>)=>void=} onComplete Form completion callback.
 */

/**
 * An error representing a state where a required form value is missing.
 */
export class RequiredValueMissingError extends Error {}

/**
 * Given a step object and current set of form values, returns true if the form values would satisfy
 * the validity requirements of the step.
 *
 * @param {FormStep} step Form step.
 * @param {Record<string,any>} values Current form values.
 */
function getValidationErrors(step, values) {
  const { validate = () => [] } = step;
  return validate(values);
}

/**
 * Given a step object and current set of form values, returns true if the form values would satisfy
 * the validity requirements of the step.
 *
 * @param {FormStep} step Form step.
 * @param {Record<string,any>} values Current form values.
 */
export function isStepValid(step, values) {
  const errors = getValidationErrors(step, values);
  return !errors || !Object.keys(errors).length;
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
function FormSteps({
  steps = [],
  onComplete = () => {},
  initialValues = {},
  initialActiveErrors = [],
  initialStep,
}) {
  const [values, setValues] = useState(initialValues);
  const [activeErrors, setActiveErrors] = useState(initialActiveErrors);
  const formRef = useRef(/** @type {?HTMLFormElement} */ (null));
  const headingRef = useRef(/** @type {?HTMLHeadingElement} */ (null));
  const [stepName, setStepName] = useHistoryParam('step', initialStep);
  const { t } = useI18n();
  const fields = useRef(/** @type {Record<string,FieldsRefEntry>} */ ({}));
  const didSubmitWithErrors = useRef(false);
  useEffect(() => {
    if (
      activeErrors.length &&
      (didSubmitWithErrors.current || activeErrors === initialActiveErrors)
    ) {
      const firstActiveError = activeErrors[0];
      fields.current[firstActiveError.field]?.element?.focus();
    }

    didSubmitWithErrors.current = false;
  }, [activeErrors]);

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

    // Treat explicit initial step the same as step transition, placing focus to header.
    if (initialStep && !initialActiveErrors.length && headingRef.current) {
      headingRef.current.focus();
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

    const nextActiveErrors = activeErrors.length
      ? [...activeErrors] // Create a clone to force a render.
      : getValidationErrors(effectiveStep, values);

    if (nextActiveErrors.length) {
      setActiveErrors(nextActiveErrors);
      didSubmitWithErrors.current = true;
      return;
    }

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

    headingRef.current?.focus();
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
        errors={activeErrors}
        onChange={(nextValuesPatch) => {
          setValues((prevValues) => ({ ...prevValues, ...nextValuesPatch }));
          setActiveErrors((prevActiveErrors) =>
            // Remove active errors if field was changed.
            prevActiveErrors.filter(({ field }) => !(field in nextValuesPatch)),
          );
        }}
        registerField={(field) => {
          if (!fields.current[field]) {
            fields.current[field] = {
              refCallback(fieldNode) {
                fields.current[field].element = fieldNode;
              },
            };
          }

          return fields.current[field].refCallback;
        }}
      />
      <Button type="submit" isPrimary className="margin-y-5">
        {t(isLastStep ? 'forms.buttons.submit.default' : 'forms.buttons.continue')}
      </Button>
    </form>
  );
}

export default FormSteps;
