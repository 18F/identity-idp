import Modal from './modal';

window.LoginGov = window.LoginGov || {};
const { LoginGov } = window;
const TrapModal = Modal;

LoginGov.Modal = TrapModal;

export { TrapModal as Modal };
