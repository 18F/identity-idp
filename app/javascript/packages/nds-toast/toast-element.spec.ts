import sinon from 'sinon';
import './toast-element';

describe('NDS ToastElement', () => {
  let clock: sinon.SinonFakeTimers;

  beforeEach(() => {
    clock = sinon.useFakeTimers();
  });

  afterEach(() => {
    clock.restore();
    document.body.innerHTML = '';
  });

  function addToast(attrs = '') {
    document.body.insertAdjacentHTML(
      'beforeend',
      `<lg-toast class="toast" data-open="false" ${attrs}>
         <div class="toast__announcement" data-nds-toast-announcement>
           <span class="toast__icon"></span>
           <p class="toast__text">Saved</p>
         </div>
       </lg-toast>`,
    );
    return document.querySelector('lg-toast') as HTMLElementTagNameMap['lg-toast'];
  }

  it('opens after the show delay and marks the announcement live', () => {
    const toast = addToast('data-show-delay="500" data-dismiss-after="3000"');
    expect(toast.dataset.open).to.equal('false');

    clock.tick(500);
    clock.next();

    expect(toast.dataset.open).to.equal('true');
    const announcement = toast.querySelector('[data-nds-toast-announcement]')!;
    expect(announcement.getAttribute('role')).to.equal('status');
    expect(announcement.getAttribute('aria-live')).to.equal('polite');
  });

  it('auto-dismisses after dismiss_after (reduced-motion removes immediately)', () => {
    sinon.stub(window, 'matchMedia').returns({ matches: true } as MediaQueryList);
    const toast = addToast('data-show-delay="500" data-dismiss-after="3000"');

    clock.tick(500);
    clock.next();
    expect(toast.dataset.open).to.equal('true');

    clock.tick(3000);
    expect(toast.dataset.open).to.equal('false');
    expect(document.querySelector('lg-toast')).to.be.null();
    (window.matchMedia as sinon.SinonStub).restore();
  });

  it('dismisses on click', () => {
    sinon.stub(window, 'matchMedia').returns({ matches: true } as MediaQueryList);
    const toast = addToast('data-show-delay="0" data-dismiss-after="0"');
    clock.tick(0);
    clock.next();

    toast.dispatchEvent(new MouseEvent('click'));
    expect(document.querySelector('lg-toast')).to.be.null();
    (window.matchMedia as sinon.SinonStub).restore();
  });

  it('does not auto-dismiss when dismiss_after <= 0', () => {
    const toast = addToast('data-show-delay="0" data-dismiss-after="0"');
    clock.tick(0);
    clock.next();
    expect(toast.dataset.open).to.equal('true');

    clock.tick(100000);
    expect(toast.dataset.open).to.equal('true');
    expect(document.querySelector('lg-toast')).to.not.be.null();
  });
});
