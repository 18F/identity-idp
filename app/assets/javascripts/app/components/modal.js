import 'classList.js'

const STATES = {
  HIDE: 'hide',
  SHOW: 'show'
};

class Modal {
  static build(options) {
    const modal = new Modal(options);

    if (options.toggle) {
      modal.toggle();
    }

    return modal;
  }

  constructor(options) {
    this.el = document.querySelector(options.el);
    this.shown = false;
  }

  toggle() {
    this.shown ? this.hide() : this.show();
  }

  show(target) {
    const el = target || this.el;

    this.shown = true;
    el.classList.remove(STATES.HIDE);

    const emitShow = new Event(STATES.SHOW);
    el.dispatchEvent(emitShow);
  }

  hide(target) {
    const el = target || this.el;
    this.shown = false;

    el.classList.add(STATES.HIDE);

    const emitHide = new Event(STATES.HIDE);
    el.dispatchEvent(emitHide);
  }

  on(event, callback) {
    this.el.addEventListener(event, callback);
  }

  _bindEvents() {
    [].slice.call(this.el.querySelectorAll('[data-dismiss]')).forEach((el) => {
      el.addEventListener('click', (event) => {
        this.hide();
      });
    })
  }
}

export default Modal;
