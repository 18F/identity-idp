import { accordion, banner, navigation } from 'identity-style-guide';
import domready from 'domready';
import Modal from './modal';

window.LoginGov = window.LoginGov || {};
window.LoginGov.Modal = Modal;

const components = [accordion, banner, navigation];
domready(() => components.forEach((component) => component.on()));
