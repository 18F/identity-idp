import { useEffect, useRef, useState, createContext, useContext } from 'react';
import { Alert } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import Button from './button';
import FormErrorMessage, { RequiredValueMissingError } from './form-error-message';
import PromptOnNavigate from './prompt-on-navigate';
import useHistoryParam from '../hooks/use-history-param';
import useForceRender from '../hooks/use-force-render';
import useDidUpdateEffect from '../hooks/use-did-update-effect';
import useIfStillMounted from '../hooks/use-if-still-mounted';
import './form-steps.scss';

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
 * @typedef {(
 *   field:string,
 *   options?:Partial<FormStepRegisterFieldOptions>
 * )=>undefined|import('react').RefCallback<HTMLElement>} RegisterFieldCallback
 */

/**
 * @typedef {(error:Error, options?: {field?: string?})=>void} OnErrorCallback
 */

/**
 * @typedef FormStepComponentProps
 *
 * @prop {(nextValues:Partial<V>)=>void} onChange Update values, merging with existing values.
 * @prop {OnErrorCallback} onError Trigger a field error.
 * @prop {Partial<V>} value Current values.
 * @prop {FormStepError<V>[]} errors Current active errors.
 * @prop {RegisterFieldCallback} registerField Registers field by given name, returning ref
 * assignment function.
 *
 * @template V
 */

/**
 * @typedef FormStep
 *
 * @prop {string} name Step name, used in history parameter.
 * @prop {import('react').FC<FormStepComponentProps<Record<string,any>>>} form Step form component.
 * @prop {(object)=>boolean=} validator Optional function to validate values for the step
 */

/**
 * @typedef FieldsRefEntry
 *
 * @prop {import('react').RefCallback<HTMLElement>} refCallback Ref callback.
 * @prop {boolean} isRequired Whether field is required.
 * @prop {HTMLElement?} element Element assigned by ref callback.
 */

/**
 * @typedef FormStepsProps
 *
 * @prop {FormStep[]=} steps Form steps.
 * @prop {Record<string,any>=} initialValues Form values to populate initial state.
 * @prop {FormStepError<Record<string,Error>>[]=} initialActiveErrors Errors to initialize state.
 * @prop {boolean=} autoFocus Whether to automatically focus heading on mount.
 * @prop {(values:Record<string,any>)=>void=} onComplete Form completion callback.
 * @prop {()=>void=} onStepChange Callback triggered on step change.
 */

/**
 * @typedef FormStepsContext
 *
 * @prop {boolean} isLastStep Whether the current step is the last step in the flow.
 * @prop {boolean} canContinueToNextStep Whether the user can proceed to the next step.
 * @prop {() => void} onPageTransition Callback invoked when content is reset in a page transition.
 */

export const FormStepsContext = createContext(
  /** @type {FormStepsContext} */ ({
    isLastStep: true,
    canContinueToNextStep: true,
    onPageTransition: () => {},
  }),
);

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
 * Returns the first element matched to a field from a set of errors, if exists.
 *
 * @param {FormStepError<Record<string,Error>>[]} errors Active form step errors.
 * @param {Record<string,FieldsRefEntry>} fields Current fields.
 *
 * @return {HTMLElement=}
 */
function getFieldActiveErrorFieldElement(errors, fields) {
  const error = errors.find(({ field }) => fields[field]?.element);

  if (error) {
    return fields[error.field].element || undefined;
  }
}

/**
 * @param {FormStepsProps} props Props object.
 */
function FormSteps({
  steps = [],
  onComplete = () => {},
  onStepChange = () => {},
  initialValues = {},
  initialActiveErrors = [],
  autoFocus,
}) {
  const [values, setValues] = useState(initialValues);
  const [activeErrors, setActiveErrors] = useState(initialActiveErrors);
  const formRef = useRef(/** @type {?HTMLFormElement} */ (null));
  const [stepName, setStepName] = useHistoryParam('step', null);
  const [stepErrors, setStepErrors] = useState(/** @type {Error[]} */ ([]));
  const fields = useRef(/** @type {Record<string,FieldsRefEntry>} */ ({}));
  const didSubmitWithErrors = useRef(false);
  const forceRender = useForceRender();
  const ifStillMounted = useIfStillMounted();
  useEffect(() => {
    if (activeErrors.length && didSubmitWithErrors.current) {
      getFieldActiveErrorFieldElement(activeErrors, fields.current)?.focus();
    }

    didSubmitWithErrors.current = false;
  }, [activeErrors]);

  const stepIndex = Math.max(getStepIndexByName(steps, stepName), 0);
  const step = steps[stepIndex];

  /**
   * After a change in content, maintain focus by resetting to the beginning of the new content.
   */
  function onPageTransition() {
    const firstElementChild = formRef.current?.firstElementChild;
    if (firstElementChild instanceof window.HTMLElement) {
      firstElementChild.classList.add('form-steps__focus-anchor');
      firstElementChild.setAttribute('tabindex', '-1');
      firstElementChild.focus();
    }

    setStepName(stepName);
  }

  useEffect(() => {
    // Treat explicit initial step the same as step transition, placing focus to header.
    if (autoFocus) {
      onPageTransition();
    }
  }, []);

  useEffect(() => {
    if (stepErrors.length) {
      onPageTransition();
    }
  }, [stepErrors]);

  useDidUpdateEffect(onStepChange, [step]);
  useDidUpdateEffect(onPageTransition, [step]);

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

  // An empty steps array is allowed, in which case there is nothing to render.
  if (!step) {
    return null;
  }

  const unknownFieldErrors = activeErrors.filter((error) => !fields.current[error.field]?.element);
  const isValidStep = step.validator?.(values) ?? true;
  const hasUnresolvedFieldErrors =
    activeErrors.length && activeErrors.length > unknownFieldErrors.length;
  const canContinueToNextStep = isValidStep && !hasUnresolvedFieldErrors;

  /**
   * Increments state to the next step, or calls onComplete callback if the current step is the last
   * step.
   *
   * @type {import('react').FormEventHandler}
   */
  function toNextStep(event) {
    event.preventDefault();

    // Don't proceed if field errors have yet to be resolved.
    if (hasUnresolvedFieldErrors) {
      setActiveErrors(Array.from(activeErrors));
      didSubmitWithErrors.current = true;
      return;
    }

    const nextActiveErrors = getValidationErrors();
    setActiveErrors(nextActiveErrors);
    didSubmitWithErrors.current = true;
    if (nextActiveErrors.length) {
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
  }

  const { form: Form, name } = step;
  const isLastStep = stepIndex + 1 === steps.length;

  return (
    <form ref={formRef} onSubmit={toNextStep}>
      {Object.keys(values).length > 0 && <PromptOnNavigate />}
      {stepErrors.concat(unknownFieldErrors.map(({ error }) => error)).map((error) => (
        <Alert key={error.message} type="error" className="margin-bottom-4">
          <FormErrorMessage error={error} isDetail />
        </Alert>
      ))}
      <FormStepsContext.Provider value={{ isLastStep, canContinueToNextStep, onPageTransition }}>
        <Form
          key={name}
          value={values}
          errors={activeErrors}
          onChange={ifStillMounted((nextValuesPatch) => {
            setActiveErrors((prevActiveErrors) =>
              prevActiveErrors.filter(({ field }) => !(field in nextValuesPatch)),
            );
            setValues((prevValues) => ({ ...prevValues, ...nextValuesPatch }));
          })}
          onError={ifStillMounted((error, { field } = {}) => {
            if (field) {
              setActiveErrors((prevActiveErrors) => prevActiveErrors.concat({ field, error }));
            } else {
              setStepErrors([error]);
            }
          })}
          registerField={(field, options = {}) => {
            if (!fields.current[field]) {
              fields.current[field] = {
                refCallback(fieldNode) {
                  fields.current[field].element = fieldNode;

                  if (activeErrors.length) {
                    forceRender();
                  }
                },
                element: null,
                isRequired: !!options.isRequired,
              };
            }

            return fields.current[field].refCallback;
          }}
        />
      </FormStepsContext.Provider>
    </form>
  );
}

export function FormStepsContinueButton() {
  const { canContinueToNextStep, isLastStep } = useContext(FormStepsContext);
  const { t } = useI18n();

  return (
    <Button
      type="submit"
      isBig
      isWide
      className="display-block margin-y-5"
      isVisuallyDisabled={!canContinueToNextStep}
    >
      {isLastStep ? t('forms.buttons.submit.default') : t('forms.buttons.continue')}
    </Button>
  );
}

export default FormSteps;
