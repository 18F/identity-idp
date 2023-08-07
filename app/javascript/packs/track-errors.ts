import { trackError } from '@18f/identity-analytics';

export interface WindowWithInitialErrors extends Window {
  _e: ErrorEvent[];
}

declare let window: WindowWithInitialErrors;

const { _e: initialErrors } = window;

const handleErrorEvent = (event: ErrorEvent) => trackError(event.error);
initialErrors.forEach(handleErrorEvent);
window.addEventListener('error', handleErrorEvent);
