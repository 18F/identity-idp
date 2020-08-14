import focusTrapProxy from './focus-trap-proxy';
import modal from './modal';

window.LoginGov = window.LoginGov || {};
const { LoginGov } = window;
const trapModal = modal(focusTrapProxy);

LoginGov.Modal = trapModal;

export { trapModal as Modal };
