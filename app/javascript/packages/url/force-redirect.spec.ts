import { useSandbox } from '@18f/identity-test-helpers';
import forceRedirect from './force-redirect';

describe('forceRedirect', () => {
  const sandbox = useSandbox();

  afterEach(() => {
    window.onbeforeunload = null;
  });

  it('navigates to the given URL, bypassing any unload protection', () => {
    const onbeforeunload = sandbox.stub();
    const navigate = sandbox.stub();
    const url = '/';
    window.onbeforeunload = onbeforeunload;

    forceRedirect(url, navigate);

    expect(navigate).to.have.been.calledWith(url);
    expect(onbeforeunload).not.to.have.been.called();
  });
});
