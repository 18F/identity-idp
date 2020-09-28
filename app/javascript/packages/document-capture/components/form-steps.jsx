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
 * @typedef FormStepRegisterFieldOptions
 *
 * @prop {boolean} isRequired Whether field is required.
 */

/**
 * @typedef FormStepComponentProps
 *
 * @prop {(nextValues:Partial<V>)=>void} onChange Values change callback, merged with
 * existing values.
 * @prop {Partial<V>} value Current values.
 * @prop {FormStepError<V>[]=} errors Current active errors.
 * @prop {(
 *   field:string,
 *   options?:Partial<FormStepRegisterFieldOptions>
 * )=>undefined|import('react').RefCallback<HTMLElement>} registerField Registers field
 * by given name, returning ref assignment function.
 *
 * @template V
 */

/**
 * @typedef FormStep
 *
 * @prop {string} name Step name, used in history parameter.
 * @prop {string} title Step title, shown as heading.
 * @prop {import('react').FC<FormStepComponentProps<Record<string,any>>>} form Step form component.
 * @prop {import('react').FC=} footer Optional step footer component.
 */

/**
 * @typedef FieldsRefEntry
 *
 * @prop {import('react').RefCallback<HTMLElement>} refCallback Ref callback.
 * @prop {boolean} isRequired Whether field is required.
 * @prop {HTMLElement?=} element Element assigned by ref callback.
 */

/**
 * @typedef FormStepsProps
 *
 * @prop {FormStep[]=} steps Form steps.
 * @prop {Record<string,any>=} initialValues Form values to populate initial state.
 * @prop {boolean=} autoFocus Whether to automatically focus heading on mount.
 * @prop {(values:Record<string,any>)=>void=} onComplete Form completion callback.
 */

/**
 * An error representing a state where a required form value is missing.
 */
export class RequiredValueMissingError extends Error {}

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
 * @param {FormStepsProps} props Props object.
 */
function FormSteps({ steps = [], onComplete = () => {}, initialValues = {}, autoFocus }) {
  const [values, setValues] = useState(initialValues);
  const [activeErrors, setActiveErrors] = useState(
    /** @type {FormStepError<Record<string,Error>>[]=} */ (undefined),
  );
  const formRef = useRef(/** @type {?HTMLFormElement} */ (null));
  const headingRef = useRef(/** @type {?HTMLHeadingElement} */ (null));
  const [stepName, setStepName] = useHistoryParam('step', null);
  const { t } = useI18n();
  const fields = useRef(/** @type {Record<string,FieldsRefEntry>} */ ({}));
  const didSubmitWithErrors = useRef(false);
  useEffect(() => {
    if (activeErrors?.length && didSubmitWithErrors.current) {
      const firstActiveError = activeErrors[0];
      fields.current[firstActiveError.field]?.element?.focus();
    }

    didSubmitWithErrors.current = false;
  }, [activeErrors]);

  const stepIndex = Math.max(getStepIndexByName(steps, stepName), 0);
  const step = steps[stepIndex];

  useEffect(() => {
    // Treat explicit initial step the same as step transition, placing focus to header.
    if (autoFocus && headingRef.current) {
      headingRef.current.focus();
    }
  }, []);

  useEffect(() => {
    // Errors are assigned at the first attempt to submit. Once errors are assigned, track value
    // changes to remove validation errors as they become resolved.
    if (activeErrors) {
      const nextActiveErrors = getValidationErrors();
      setActiveErrors(nextActiveErrors);
    }
  }, [values]);

  // An empty steps array is allowed, in which case there is nothing to render.
  if (!step) {
    return null;
  }

  /**
   * Returns array of form errors for the current set of values.
   *
   * @return {FormStepError<Record<string,Error>>[]}
   */
  function getValidationErrors() {
    return Object.keys(fields.current).reduce((result, key) => {
      const { element, isRequired } = fields.current[key];
      const isActive = !!element;

      if (isActive && isRequired && !values[key]) {
        result = result.concat({ field: key, error: new RequiredValueMissingError() });
      }

      return result;
    }, /** @type {FormStepError<Record<string,Error>>[]} */ ([]));
  }

  /**
   * Increments state to the next step, or calls onComplete callback if the current step is the last
   * step.
   *
   * @type {import('react').FormEventHandler}
   */
  function toNextStep(event) {
    event.preventDefault();

    const nextActiveErrors = getValidationErrors();
    setActiveErrors(nextActiveErrors);
    didSubmitWithErrors.current = true;
    if (nextActiveErrors?.length) {
      return;
    }

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

    headingRef.current?.focus();
  }

  const { form: Form, footer: Footer, name, title } = step;
  const isLastStep = stepIndex + 1 === steps.length;

  return (
    <form ref={formRef} onSubmit={toNextStep}>
      <PageHeading key="title" ref={headingRef} tabIndex={-1}>
        {title}
      </PageHeading>
      <Form
        key={name}
        value={values}
        errors={activeErrors}
        onChange={(nextValuesPatch) => {
          setValues((prevValues) => ({ ...prevValues, ...nextValuesPatch }));
        }}
        registerField={(field, options = {}) => {
          if (!fields.current[field]) {
            fields.current[field] = {
              refCallback(fieldNode) {
                fields.current[field].element = fieldNode;
              },
              isRequired: !!options.isRequired,
            };
          }

          return fields.current[field].refCallback;
        }}
      />
      <Button type="submit" isPrimary className="margin-y-5">
        {t(isLastStep ? 'forms.buttons.submit.default' : 'forms.buttons.continue')}
      </Button>
      {Footer && <Footer />}
    </form>
  );
}

export default FormSteps;
