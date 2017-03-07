import Modal from './modal';
import Accordion from './accordion';

const LoginGov = window.LoginGov = (window.LoginGov || {});

LoginGov.Modal = Modal;

document.addEventListener('DOMContentLoaded', () => {
  const elements = document.querySelectorAll('.accordion');

  LoginGov.accordions = [].slice.call(elements).map((element) => {
    const accordion = new Accordion(element);
    accordion.setup();

    return accordion;
  });
});
