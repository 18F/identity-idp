import sinon from 'sinon';

/**
 * Returns an instance of a Sinon sandbox, and automatically restores all stubbed methods after each
 * test case.
 *
 * @param {sinon.SinonSandboxConfig=} config
 */
export function useSandbox(config) {
  const sandbox = sinon.createSandbox(config);

  afterEach(() => {
    sandbox.restore();
  });

  return sandbox;
}
