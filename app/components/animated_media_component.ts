const prefersReducedMotion = () =>
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;

class AnimatedMediaElement extends HTMLElement {
  #image!: HTMLImageElement;

  #frame!: HTMLCanvasElement;

  #button!: HTMLButtonElement;

  #src = '';

  #playing = true;

  connectedCallback() {
    this.#image = this.querySelector('.ads-animated-media__image')!;
    this.#frame = this.querySelector('.ads-animated-media__frame')!;
    this.#button = this.querySelector('.ads-animated-media__toggle')!;
    this.#src = this.#image.getAttribute('src') || this.#image.currentSrc || this.#image.src;
    this.#button.addEventListener('click', this.#onToggle);

    if (prefersReducedMotion()) {
      this.#whenReady(() => this.pause());
    }
  }

  disconnectedCallback() {
    this.#button?.removeEventListener('click', this.#onToggle);
  }

  get playing(): boolean {
    return this.#playing;
  }

  pause() {
    if (!this.#playing) {
      return;
    }

    if (!this.#image.complete || !this.#image.naturalWidth) {
      this.#whenReady(() => this.pause());
      return;
    }

    this.#frame.width = this.#image.naturalWidth;
    this.#frame.height = this.#image.naturalHeight;
    const context = this.#frame.getContext('2d');
    if (!context) {
      return;
    }

    context.drawImage(this.#image, 0, 0);

    // Prefer a static PNG src (setAttribute avoids Image.prototype.src stubs).
    // Fall back to a visible canvas frame if toDataURL fails (tainted canvas).
    try {
      this.#image.setAttribute('src', this.#frame.toDataURL('image/png'));
      this.#showImage();
    } catch {
      this.#showFrame();
      this.#image.removeAttribute('src');
    }

    this.#setPlaying(false);
  }

  play() {
    if (this.#playing || !this.#src) {
      return;
    }

    this.#showImage();
    this.#image.setAttribute('src', this.#src);
    this.#setPlaying(true);
  }

  #showImage() {
    this.#image.hidden = false;
    this.#frame.hidden = true;
    this.#frame.removeAttribute('role');
    this.#frame.removeAttribute('aria-label');
    this.#frame.setAttribute('aria-hidden', 'true');
  }

  #showFrame() {
    this.#frame.setAttribute('role', 'img');
    this.#frame.setAttribute('aria-label', this.#image.alt);
    this.#frame.removeAttribute('aria-hidden');
    this.#frame.hidden = false;
    this.#image.hidden = true;
  }

  #onToggle = () => {
    if (this.#playing) {
      this.pause();
    } else {
      this.play();
    }
  };

  #setPlaying(playing: boolean) {
    this.#playing = playing;
    this.dataset.playing = String(playing);
    this.#button.setAttribute(
      'aria-label',
      playing ? this.dataset.pauseLabel! : this.dataset.playLabel!,
    );
  }

  #whenReady(callback: () => void) {
    if (this.#image.complete && this.#image.naturalWidth) {
      callback();
      return;
    }

    this.#image.addEventListener('load', callback, { once: true });
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'lg-animated-media': AnimatedMediaElement;
  }
}

if (!customElements.get('lg-animated-media')) {
  customElements.define('lg-animated-media', AnimatedMediaElement);
}

export default AnimatedMediaElement;
