/* eslint-disable no-console */

import sinon from 'sinon';
import { format } from 'util';

/**
 * Chai plugin which adds chainable `logged` method, to be used in combination with
 * `useConsoleLogSpy` test helper to validate expected console logging.
 *
 * @see https://www.chaijs.com/guide/plugins/
 * @see https://www.chaijs.com/api/plugins/
 *
 * @param {import('chai')}                chai  Chai object.
 * @param {import('chai/lib/chai/utils')} utils Chai plugin utilities.
 */
export function chaiConsoleSpy(chai, utils) {
  utils.addChainableMethod(
    chai.Assertion.prototype,
    'loggedError',
    (message) => {
      if (message) {
        const index = console.unverifiedCalls.findIndex((calledMessage) =>
          message instanceof RegExp ? message.test(calledMessage) : message === calledMessage,
        );
        let error = `Expected console to have logged: ${message}. `;
        error += console.unverifiedCalls
          ? `Console logged with: ${console.unverifiedCalls.join(', ')}`
          : 'Console did not log.';

        expect(index).to.not.equal(-1, error);

        console.unverifiedCalls.splice(index, 1);
      } else {
        console.unverifiedCalls = [];
      }
    },
    undefined,
  );
}

/**
 * Test lifecycle helper which stubs `console.error` and verifies that any logging which occurs to
 * this method is validated using the `logged` chainable assertion implemented by the
 * `chaiConsoleSpy` Chai plugin.
 */
export function useConsoleLogSpy() {
  beforeEach(() => {
    console.unverifiedCalls = [];
    sinon.stub(console, 'error').callsFake((message, ...args) => {
      console.unverifiedCalls = console.unverifiedCalls.concat(format(message, ...args));
    });
  });

  afterEach(() => {
    console.error.restore();
    expect(console.unverifiedCalls).to.be.empty(
      `Unexpected console logging: ${console.unverifiedCalls.join(', ')}`,
    );
  });
}
