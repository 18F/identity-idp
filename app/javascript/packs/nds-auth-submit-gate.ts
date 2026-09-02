import { bindFormSubmitters } from '@18f/identity-input-validation/form-submitters';

// Disables submit buttons on NDS auth forms (marked `data-nds-submit-gate`)
// until their constraint-validation requirements are met — e.g. the sign-in
// form's submit stays disabled until email and password are filled. Reuses the
// shared, tested `bindFormSubmitters` gating (input/change sync + blur/mousedown
// handling). Safe to run repeatedly; `bindFormSubmitters` binds once per form.
export function initialize(root: ParentNode = document) {
  root.querySelectorAll<HTMLFormElement>('form[data-nds-submit-gate]').forEach(bindFormSubmitters);
}

if (process.env.NODE_ENV !== 'test') {
  initialize();
}
