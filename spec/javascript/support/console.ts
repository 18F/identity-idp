/* eslint-disable no-console */

import sinon from 'sinon';
import { format } from 'util';

declare global {
  namespace Chai {
    interface Assertion {
      loggedError: (message: string | RegExp) => Chai.Assertion;
    }
  }
}

type ExtendedConsole = typeof console & { unverifiedCalls: string[] };

const logger = console as ExtendedConsole;

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
        const index = logger.unverifiedCalls.findIndex((calledMessage) =>
          message instanceof RegExp ? message.test(calledMessage) : message === calledMessage,
        );
        let error = `Expected console to have logged: ${message}. `;
        error += logger.unverifiedCalls
          ? `Console logged with: ${logger.unverifiedCalls.join(', ')}`
          : 'Console did not log.';

        expect(index).to.not.equal(-1, error);

        logger.unverifiedCalls.splice(index, 1);
      } else {
        logger.unverifiedCalls = [];
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
  let originalConsoleError;
  beforeEach(() => {
    logger.unverifiedCalls = [];
    originalConsoleError = logger.error;
    logger.error = sinon.stub().callsFake((message, ...args) => {
      logger.unverifiedCalls = (console as ExtendedConsole).unverifiedCalls.concat(
        format(message, ...args),
      );
    });
  });

  afterEach(() => {
    logger.error = originalConsoleError;
    expect(logger.unverifiedCalls).to.be.empty(
      `Unexpected console logging: ${logger.unverifiedCalls.join(', ')}`,
    );
  });
}
