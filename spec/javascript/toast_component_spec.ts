import '../../app/components/toast_component';

describe('ToastComponent', () => {
  beforeEach(() => {
    Object.defineProperty(window, 'matchMedia', {
      configurable: true,
      value: () => ({ matches: true }),
    });
  });

  const renderToast = () => {
    document.body.innerHTML = `
      <lg-toast class="ads-toast" data-open="false" data-show-delay="0" data-dismiss-after="0">
        <div data-ads-toast-announcement>Saved</div>
      </lg-toast>
    `;
    return document.querySelector('lg-toast')!;
  };

  it('announces only when the delayed visual entry begins', async () => {
    const toast = renderToast();
    const announcement = toast.querySelector('[data-ads-toast-announcement]')!;

    expect(announcement.hasAttribute('role')).to.be.false();
    await new Promise((resolve) => window.setTimeout(resolve, 30));

    expect(toast.dataset.open).to.equal('true');
    expect(announcement.getAttribute('role')).to.equal('status');
    expect(announcement.getAttribute('aria-live')).to.equal('polite');
  });

  it('moves itself to document.body so it escapes page stacking contexts', () => {
    document.body.innerHTML = '<main id="main"></main>';
    const main = document.getElementById('main')!;
    main.innerHTML = `
      <lg-toast class="ads-toast" data-open="false" data-show-delay="0" data-dismiss-after="0">
        <div data-ads-toast-announcement>Saved</div>
      </lg-toast>
    `;

    const toast = document.querySelector('lg-toast')!;
    expect(toast.parentElement).to.equal(document.body);
  });

  it('dismisses when the toast itself is clicked', async () => {
    const toast = renderToast();
    await new Promise((resolve) => window.setTimeout(resolve, 30));

    toast.click();

    expect(document.body.contains(toast)).to.be.false();
  });
});
