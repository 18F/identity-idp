/* eslint-disable no-underscore-dangle */

export interface WindowWithInitialErrors extends Window {
  _initialErrors: ErrorEvent[] | undefined;
}

declare let window: WindowWithInitialErrors;

window._initialErrors = [];

function handleErrorEvent(event: ErrorEvent) {
  if (window._initialErrors) {
    window._initialErrors.push(event);
  } else {
    window.removeEventListener('error', handleErrorEvent);
  }
}

window.addEventListener('error', handleErrorEvent);
