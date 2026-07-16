import sinon from 'sinon';
import { getByRole } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import '../../app/components/animated_media_component';

describe('AnimatedMediaComponent', () => {
  const sandbox = sinon.createSandbox();
  const frozenSrc = 'data:image/png;base64,frozen';

  afterEach(() => {
    sandbox.restore();
    document.body.innerHTML = '';
  });

  function stubMatchMedia(matches: boolean) {
    Object.defineProperty(window, 'matchMedia', {
      configurable: true,
      value: () => ({ matches, addListener() {}, removeListener() {} }),
    });
  }

  function createMedia({
    complete = true,
    tainted = false,
  }: { complete?: boolean; tainted?: boolean } = {}) {
    const src = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7';
    const element = document.createElement('lg-animated-media');
    element.className = 'ads-animated-media';
    element.dataset.playing = 'true';
    element.dataset.pauseLabel = 'Pause animation';
    element.dataset.playLabel = 'Play animation';
    element.innerHTML = `
      <img class="ads-animated-media__image" src="${src}" alt="Demo" width="2" height="2" />
      <canvas class="ads-animated-media__frame" hidden aria-hidden="true"></canvas>
      <button type="button" class="ads-animated-media__toggle" aria-label="Pause animation">
        Toggle
      </button>
    `;

    const image = element.querySelector('img') as HTMLImageElement;
    let isComplete = complete;
    let naturalSize = complete ? 2 : 0;
    Object.defineProperty(image, 'complete', { configurable: true, get: () => isComplete });
    Object.defineProperty(image, 'naturalWidth', {
      configurable: true,
      get: () => naturalSize,
    });
    Object.defineProperty(image, 'naturalHeight', {
      configurable: true,
      get: () => naturalSize,
    });

    const drawImage = sandbox.spy();
    sandbox.stub(HTMLCanvasElement.prototype, 'getContext').returns({ drawImage } as any);
    if (tainted) {
      sandbox.stub(HTMLCanvasElement.prototype, 'toDataURL').throws(new Error('tainted'));
    } else {
      sandbox.stub(HTMLCanvasElement.prototype, 'toDataURL').returns(frozenSrc);
    }

    return {
      element,
      image,
      src,
      drawImage,
      finishLoad() {
        isComplete = true;
        naturalSize = 2;
        image.dispatchEvent(new Event('load'));
      },
    };
  }

  it('freezes the gif on pause and restores it on play', async () => {
    stubMatchMedia(false);
    const { element, image, src, drawImage } = createMedia();
    document.body.appendChild(element);
    const button = getByRole(element, 'button');
    const frame = element.querySelector('canvas') as HTMLCanvasElement;

    await userEvent.click(button);

    expect(element.dataset.playing).to.equal('false');
    expect(button.getAttribute('aria-label')).to.equal('Play animation');
    expect(drawImage.calledOnce).to.be.true();
    expect(image.hidden).to.be.false();
    expect(image.getAttribute('src')).to.equal(frozenSrc);
    expect(frame.hidden).to.be.true();

    await userEvent.click(button);

    expect(element.dataset.playing).to.equal('true');
    expect(button.getAttribute('aria-label')).to.equal('Pause animation');
    expect(image.hidden).to.be.false();
    expect(image.getAttribute('src')).to.equal(src);
    expect(frame.hidden).to.be.true();
  });

  it('falls back to a canvas frame when the gif cannot be snapshotted', async () => {
    stubMatchMedia(false);
    const { element, image, drawImage } = createMedia({ tainted: true });
    document.body.appendChild(element);
    const button = getByRole(element, 'button');
    const frame = element.querySelector('canvas') as HTMLCanvasElement;

    await userEvent.click(button);

    expect(element.dataset.playing).to.equal('false');
    expect(drawImage.calledOnce).to.be.true();
    expect(image.hidden).to.be.true();
    expect(image.hasAttribute('src')).to.be.false();
    expect(frame.hidden).to.be.false();
    expect(frame.getAttribute('role')).to.equal('img');
  });

  it('defers pause until the image has loaded', async () => {
    stubMatchMedia(false);
    const { element, image, drawImage, finishLoad } = createMedia({ complete: false });
    document.body.appendChild(element);
    const button = getByRole(element, 'button');

    await userEvent.click(button);

    expect(element.dataset.playing).to.equal('true');
    expect(drawImage.called).to.be.false();
    expect(image.getAttribute('src')).to.include('data:image/gif');

    finishLoad();

    expect(element.dataset.playing).to.equal('false');
    expect(button.getAttribute('aria-label')).to.equal('Play animation');
    expect(drawImage.calledOnce).to.be.true();
    expect(image.getAttribute('src')).to.equal(frozenSrc);
  });

  it('auto-pauses when prefers-reduced-motion is set', () => {
    stubMatchMedia(true);
    const { element, image } = createMedia();
    document.body.appendChild(element);

    expect(element.dataset.playing).to.equal('false');
    expect(getByRole(element, 'button').getAttribute('aria-label')).to.equal('Play animation');
    expect(image.getAttribute('src')).to.equal(frozenSrc);
  });
});
