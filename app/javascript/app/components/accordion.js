import 'classlist.js';
import Events from '../utils/events';

class Accordion extends Events {
  constructor(el) {
    super();

    this.el = el;
    this.controls = [].slice.call(el.querySelectorAll('[aria-controls]'));
    this.content = el.querySelector('.accordion-content');
    this.header = el.querySelector('.accordion-header-controls');
    this.collapsedIcon = el.querySelector('.plus-icon');
    this.shownIcon = el.querySelector('.minus-icon');

    this.handleClick = this.handleClick.bind(this);
    this.handleKeyUp = this.handleKeyUp.bind(this);
  }

  setup() {
    this.bindEvents();
    this.onInitialize();
  }

  bindEvents() {
    this.controls.forEach((control) => {
      control.addEventListener('click', this.handleClick);
      control.addEventListener('keyup', this.handleKeyUp);
    });

    if (!('animation' in this.content.style)) return;

    this.content.addEventListener('animationend', (event) => {
      const { animationName } = event;

      if (animationName === 'accordionOut') {
        this.content.classList.remove('shown');
      }
    });
  }

  onInitialize() {
    this.setExpanded(false);
    this.collapsedIcon.classList.remove('display-none');
  }

  handleClick() {
    const expandedState = this.header.getAttribute('aria-expanded');

    if (expandedState === 'false') {
      this.open();
    } else if (expandedState === 'true') {
      this.close();
    }
  }

  handleKeyUp(event) {
    const keyCode = event.keyCode || event.which;

    if (keyCode === 13 || keyCode === 32) {
      this.handleClick();
    }
  }

  setExpanded(bool) {
    this.header.setAttribute('aria-expanded', bool);
  }

  open() {
    this.setExpanded(true);
    this.collapsedIcon.classList.add('display-none');
    this.shownIcon.classList.remove('display-none');
    this.content.classList.add('shown');
    this.content.classList.remove('animate-out');
    this.content.classList.add('animate-in');
    this.content.setAttribute('aria-hidden', 'false');
    this.emit('accordion.show');
  }

  close() {
    this.setExpanded(false);
    this.collapsedIcon.classList.remove('display-none');
    this.shownIcon.classList.add('display-none');
    this.content.classList.remove('animate-in');
    this.content.classList.add('animate-out');
    this.content.setAttribute('aria-hidden', 'true');
    this.emit('accordion.hide');
    this.header.focus();
  }
}

export default Accordion;
