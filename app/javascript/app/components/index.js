import { accordion, accordionCloseButton, banner, navigation } from 'identity-style-guide';
import domready from 'domready';
import Modal from './modal';

window.LoginGov = window.LoginGov || {};
window.LoginGov.Modal = Modal;

const components = [accordion, accordionCloseButton, banner, navigation];
domready(() => components.forEach((component) => component.on()));
