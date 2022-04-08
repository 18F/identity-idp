import { render } from 'react-dom';
import { VerifyFlow } from '@18f/identity-verify-flow';

const appRoot = document.getElementById('app-root')!;
render(<VerifyFlow />, appRoot);
