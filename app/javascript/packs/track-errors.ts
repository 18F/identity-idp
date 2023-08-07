/* eslint-disable no-underscore-dangle */

import { trackError } from '@18f/identity-analytics';
import type { WindowWithInitialErrors } from './track-errors-prelude';

declare let window: WindowWithInitialErrors;

const handleErrorEvent = (event: ErrorEvent) => trackError(event.error);
window._initialErrors!.forEach(handleErrorEvent);
delete window._initialErrors;
window.addEventListener('error', handleErrorEvent);
