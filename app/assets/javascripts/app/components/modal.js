import 'classlist.js';

const STATES = {
  HIDE: 'hide',
  SHOW: 'show',
};

class Modal {
  constructor(options) {
    this.el = document.querySelector(options.el);
    this.shown = false;
  }

  toggle() {
    if (this.shown) {
      this.hide();
    } else {
      this.show();
    }
  }

  show(target) {
    this._setElementVisibility(target, true);
    this._emitEvent(target, STATES.SHOW);
  }

  hide(target) {
    this._setElementVisibility(target, false);
    this._emitEvent(target, STATES.HIDE);
  }

  on(event, callback) {
    this.el.addEventListener(event, callback);
  }

  _setElementVisibility(target = null, showing) {
    const el = target || this.el;

    this.shown = showing;
    el.classList[showing ? 'remove' : 'add'](STATES.HIDE);
    document.body.classList[showing ? 'add' : 'remove']('modal-open');
  }

  _emitEvent(target = null, eventType) {
    const emittable = new Event(eventType);
    (target || this.el).dispatchEvent(emittable);
  }

  _bindEvents() {
    [].slice.call(this.el.querySelectorAll('[data-dismiss]')).forEach((el) => {
      el.addEventListener('click', (event) => {
        event.preventDefault();
        this.hide();
      });
    });
  }
}

export default Modal;
