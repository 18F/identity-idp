import removeUnloadProtection from './remove-unload-protection';

describe('removeUnloadProtection', () => {
  afterEach(() => {
    window.onbeforeunload = null;
    window.onunload = null;
  });

  it('neutralizes navigation confirmation prompts', () => {
    window.onbeforeunload = () => {};
    window.onunload = () => {};

    removeUnloadProtection();

    expect(window.onbeforeunload).not.to.exist();
    expect(window.onunload).not.to.exist();
  });
});
