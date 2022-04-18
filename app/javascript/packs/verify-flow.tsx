import { render } from 'react-dom';
import { VerifyFlow } from '@18f/identity-verify-flow';

interface AppRootValues {
  /**
   * JSON-encoded object of initial application data.
   */
  initialValues: string;

  /**
   * The path to which the current step is appended to create the current step URL.
   */
  basePath: string;
}

interface AppRootElement extends HTMLElement {
  dataset: DOMStringMap & AppRootValues;
}

const appRoot = document.getElementById('app-root') as AppRootElement;
const { initialValues, basePath } = appRoot.dataset;

let parsedInitialValues;
try {
  parsedInitialValues = JSON.parse(initialValues);
} catch {}

render(<VerifyFlow initialValues={parsedInitialValues} basePath={basePath} />, appRoot);
