import 'classlist.js';

class Accordion {
  constructor(el) {
    this.el = el;
    this.controls = [].slice.call(el.querySelectorAll('[aria-controls]'));
    this.content = el.querySelector('.accordion-content');

    this.handleClick = this.handleClick.bind(this);
  }

  setup() {
    this.bindEvents();
    this.onInitialize();
  }

  bindEvents() {
    this.controls.forEach((control) => {
      control.addEventListener('click', this.handleClick);
    });

    if (!('animation' in this.content.style)) return;

    this.content.addEventListener('animationend', (event) => {
      const { animationName } = event;

      if (animationName === 'accordionOut') {
        this.content.classList.add('display-none');
      }
    });
  }

  onInitialize() {
    this.content.classList.add('display-none');
    this.el.setAttribute('aria-expanded', 'false');
    this.content.setAttribute('aria-hidden', 'true');
    this.content.classList.remove('accordion-init');
  }

  handleClick() {
    const { el } = this;
    const expandedState = el.getAttribute('aria-expanded');

    if (expandedState === 'false') {
      this.open();
    } else if (expandedState === 'true') {
      this.close();
    }
  }

  open() {
    this.el.setAttribute('aria-expanded', 'true');
    this.content.setAttribute('aria-hidden', 'false');
    this.content.classList.remove('display-none');
    this.content.classList.remove('animate-out');
    this.content.classList.add('animate-in');
  }

  close() {
    this.el.setAttribute('aria-expanded', 'false');
    this.content.setAttribute('aria-hidden', 'true');
    this.content.classList.remove('animate-in');
    this.content.classList.add('animate-out');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const elements = document.querySelectorAll('.accordion');

  [].slice.call(elements).forEach((element) => {
    const accordion = new Accordion(element);
    accordion.setup();
  });
});

export default Accordion;
