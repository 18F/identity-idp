import { render } from 'react-dom';
import { FormSteps } from '@18f/identity-form-steps';
import { personalKeyStep, personalKeyConfirmStep } from '@18f/identity-verify-flow';

interface AppRootValues {
  personalKey: string;
}

interface AppRootElement extends HTMLElement {
  dataset: DOMStringMap & AppRootValues;
}

const appRoot = document.getElementById('app-root') as AppRootElement;
const appForm = document.getElementById('app-form') as HTMLFormElement;

render(
  <FormSteps
    steps={[personalKeyStep, personalKeyConfirmStep]}
    initialValues={{ personalKey: appRoot.dataset.personalKey }}
    promptOnNavigate={false}
    onComplete={() => appForm.submit()}
  />,
  appRoot,
);
