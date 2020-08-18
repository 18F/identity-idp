import sinon from 'sinon';

/**
 * Returns an instance of a Sinon sandbox, and automatically restores all stubbed methods after each
 * test case.
 */
export function useSandbox() {
  const sandbox = sinon.createSandbox();

  afterEach(() => {
    sandbox.restore();
  });

  return sandbox;
}
