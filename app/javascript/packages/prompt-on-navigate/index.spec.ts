import { promptOnNavigate } from '.';

describe('promptOnNavigate', () => {
  it('prompts on navigate', () => {
    promptOnNavigate();

    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);

    expect(event.defaultPrevented).to.be.true();
    expect(event.returnValue).to.be.false();
  });

  it('cleans up after itself', () => {
    window.onbeforeunload = null;

    const cleanup = promptOnNavigate();

    expect(window.onbeforeunload).not.to.be.null();

    cleanup();

    expect(window.onbeforeunload).to.be.null();
  });

  it("does not clean up someone else's handler", () => {
    const clean = promptOnNavigate();
    const custom = () => {};
    window.onbeforeunload = custom;
    clean();
    expect(window.onbeforeunload).to.eql(custom);
  });
});
