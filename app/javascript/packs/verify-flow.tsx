import { render } from 'react-dom';
import { VerifyFlow } from '@18f/identity-verify-flow';

const appRoot = document.getElementById('app-root')!;
let initialValues;
try {
  initialValues = JSON.parse(appRoot.dataset.initialValues!);
} catch {}

render(<VerifyFlow initialValues={initialValues} />, appRoot);
