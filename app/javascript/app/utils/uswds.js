// This file serves as a minimal, progressively-enhanced entry point for the  Login.gov Design
// System component integration. It serves two purposes:
//
// 1. Require explicit opt-in to components, to avoid behaviors from being applied to legacy (ad
//    hoc) implementations.
// 2. Import the minimal behavior code for components used in the application.
//
// The specific code (notably polyfills and configuration) follows that of the default entry point
// for the design system, which can serve as reference.
//
// See: https://github.com/18F/identity-style-guide/blob/master/src/js/main.js
// See: https://github.com/uswds/uswds/blob/develop/src/js/start.js

import domready from 'domready';
import 'uswds/src/js/polyfills';
import 'uswds/src/js/config';
import accordion from 'uswds/src/js/components/accordion';

const COMPONENTS = {
  '.usa-banner': accordion,
};

domready(() => {
  Object.keys(COMPONENTS).forEach((selector) => {
    const behavior = COMPONENTS[selector];
    const target = document.querySelector(selector);
    if (target) {
      behavior.on(target);
    }
  });
});
