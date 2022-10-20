import { accordion, banner, skipnav } from 'identity-style-guide';
import Modal from './modal';

window.LoginGov = window.LoginGov || {};
window.LoginGov.Modal = Modal;

const components = [accordion, banner, skipnav];
components.forEach((component) => component.on());
