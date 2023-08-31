import { isCameraCapableMobile } from '@18f/identity-device';

if (isCameraCapableMobile()) {
  const form = document.querySelector<HTMLFormElement>('.js-consent-continue-form')!;

  // Tell the backend that we're on a device that can take its own pictures, so we don't need
  // to show the user the hybrid handoff screen.
  const input = document.createElement('input');
  input.type = 'hidden';
  input.name = 'skip_hybrid_handoff';
  form.appendChild(input);
}
