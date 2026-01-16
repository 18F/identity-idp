/* eslint-disable no-console */

import { format } from 'node:util';
import sinon from 'sinon';
import type Chai from 'chai';

declare global {
  namespace Chai {
    interface Assertion {
      loggedError: (message: string | RegExp) => Chai.Assertion;
    }
  }
}

let unverifiedCalls: string[] = [];

/**
 * Chai plugin which adds chainable `logged` method, to be used in combination with
 * `useConsoleLogSpy` test helper to validate expected console logging.
 *
 * @see https://www.chaijs.com/guide/plugins/
 * @see https://www.chaijs.com/api/plugins/
 *
 * @param chai Chai object.
 * @param utils Chai plugin utilities.
 */
export const chaiConsoleSpy: Chai.ChaiPlugin = (chai, utils) => {
  utils.addChainableMethod(
    chai.Assertion.prototype,
    'loggedError',
    (message: string | RegExp) => {
      if (message) {
        const index = unverifiedCalls.findIndex((calledMessage) =>
          message instanceof RegExp ? message.test(calledMessage) : message === calledMessage,
        );
        let error = `Expected console to have logged: ${message}. `;
        error += unverifiedCalls
          ? `Console logged with: ${unverifiedCalls.join(', ')}`
          : 'Console did not log.';

        expect(index).to.not.equal(-1, error);

        unverifiedCalls.splice(index, 1);
      } else {
        unverifiedCalls = [];
      }
    },
    undefined,
  );
};

/**
 * Test lifecycle helper which stubs `console.error` and verifies that any logging which occurs to
 * this method is validated using the `logged` chainable assertion implemented by the
 * `chaiConsoleSpy` Chai plugin.
 */
export function useConsoleLogSpy() {
  let originalConsoleError: Console['error'];
  before(() => {
    originalConsoleError = console.error;
    console.error = sinon.stub().callsFake((message, ...args) => {
      unverifiedCalls.push(format(message, ...args));
    });
  });

  beforeEach(() => {
    unverifiedCalls = [];
  });

  afterEach(() => {
    expect(unverifiedCalls).to.be.empty(
      `Unexpected console logging: ${unverifiedCalls.join(', ')}`,
    );
  });

  after(() => {
    console.error = originalConsoleError;
  });
}
