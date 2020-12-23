import { accordion, accordionCloseButton, banner, navigation, tooltip } from 'identity-style-guide';
import domready from 'domready';
import Modal from './modal';

window.LoginGov = window.LoginGov || {};
window.LoginGov.Modal = Modal;

const components = [accordion, accordionCloseButton, banner, navigation, tooltip];
domready(() => components.forEach((component) => component.on()));
