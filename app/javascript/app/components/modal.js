import 'classlist-polyfill';
import { createFocusTrap } from 'focus-trap';
import Events from '../utils/events';

const STATES = {
  HIDE: 'hide',
  SHOW: 'show',
};

class Modal extends Events {
  constructor(options) {
    super();

    this.el = document.querySelector(options.el);
    this.shown = false;
    this.trap = createFocusTrap(this.el, { escapeDeactivates: false });
  }

  toggle() {
    if (this.shown) {
      this.hide();
    } else {
      this.show();
    }
  }

  show(target) {
    this.setElementVisibility(target, true);
    this.emit(STATES.SHOW);
  }

  hide(target) {
    this.setElementVisibility(target, false);
    this.emit(STATES.HIDE);
  }

  setElementVisibility(target = null, showing) {
    const el = target || this.el;

    this.shown = showing;
    el.classList[showing ? 'remove' : 'add']('display-none');
    document.body.classList[showing ? 'add' : 'remove']('modal-open');
    this.trap[showing ? 'activate' : 'deactivate']();
  }
}

export default Modal;
