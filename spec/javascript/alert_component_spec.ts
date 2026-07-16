import '../../app/components/alert_component';

describe('AlertComponent', () => {
  const buildAlert = ({
    text = 'Short alert',
    withAction = false,
    withTitle = false,
    scrollHeight = 24,
  }: {
    text?: string;
    withAction?: boolean;
    withTitle?: boolean;
    scrollHeight?: number;
  } = {}) => {
    const actionClass = withAction ? ' ads-alert--with-action' : '';
    const title = withTitle ? '<p class="ads-alert__title">Title</p>' : '';
    const copy = withTitle
      ? `<div class="ads-alert__copy">${title}<p class="ads-alert__text">${text}</p></div>`
      : `<p class="ads-alert__text">${text}</p>`;
    const action = withAction ? '<a class="ads-alert__action" href="#">Continue</a>' : '';

    const mount = document.createElement('lg-alert');
    mount.className = 'ads-alert-mount';
    mount.dataset.open = 'true';
    mount.innerHTML = `
      <div class="ads-alert-mount__inner">
        <div class="ads-alert ads-alert--neutral${actionClass}">
          ${copy}
          ${action}
          <span class="ads-alert__spacer" aria-hidden="true"></span>
          <button type="button" class="ads-alert__close" data-dismiss>Close</button>
        </div>
      </div>
    `;

    const textEl = mount.querySelector<HTMLElement>('.ads-alert__text')!;
    textEl.style.lineHeight = '24px';
    Object.defineProperty(textEl, 'scrollHeight', {
      configurable: true,
      get: () => scrollHeight,
    });

    document.body.appendChild(mount);
    return mount;
  };

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('marks single-line alerts so the close button can center', () => {
    const alert = buildAlert({ text: 'Short alert', scrollHeight: 24 }).querySelector(
      '.ads-alert',
    )!;

    expect(alert.classList.contains('ads-alert--single-line')).to.be.true();
  });

  it('keeps multi-line, titled, and action alerts top-aligned', () => {
    expect(
      buildAlert({
        text: 'We signed you out. For your security, Login.gov ends your session when you haven’t moved to a new page for 15 minutes.',
        scrollHeight: 48,
      })
        .querySelector('.ads-alert')!
        .classList.contains('ads-alert--single-line'),
    ).to.be.false();

    document.body.innerHTML = '';
    expect(
      buildAlert({ text: 'Body', withTitle: true, scrollHeight: 24 })
        .querySelector('.ads-alert')!
        .classList.contains('ads-alert--single-line'),
    ).to.be.false();

    document.body.innerHTML = '';
    expect(
      buildAlert({ text: 'Short alert', withAction: true, scrollHeight: 24 })
        .querySelector('.ads-alert')!
        .classList.contains('ads-alert--single-line'),
    ).to.be.false();
  });
});
