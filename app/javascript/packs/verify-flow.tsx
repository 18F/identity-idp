import { render } from 'react-dom';
import { VerifyFlow } from '@18f/identity-verify-flow';

interface AppRootValues {
  /**
   * JSON-encoded object of initial application data.
   */
  initialValues: string;

  /**
   * JSON-encoded array of enabled step names.
   */
  enabledStepNames: string;

  /**
   * The path to which the current step is appended to create the current step URL.
   */
  basePath: string;

  /**
   * Application name.
   */
  appName: string;

  /**
   * URL to which user should be redirected after completing the form.
   */
  completionUrl: string;
}

interface AppRootElement extends HTMLElement {
  dataset: DOMStringMap & AppRootValues;
}

const appRoot = document.getElementById('app-root') as AppRootElement;
const { initialValues, basePath, appName, completionUrl: completionURL } = appRoot.dataset;

const initialValues = JSON.parse(initialValuesJSON);
const enabledStepNames = JSON.parse(enabledStepNamesJSON) as string[];

function onComplete() {
  window.location.href = completionURL;
}

function onComplete() {
  window.location.href = completionURL;
}

render(
  <VerifyFlow
    initialValues={parsedInitialValues}
    basePath={basePath}
    appName={appName}
    onComplete={onComplete}
  />,
  appRoot,
);
