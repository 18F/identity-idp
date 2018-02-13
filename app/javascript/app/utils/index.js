import autoLogout from './auto-logout';
import countdownTimer from './countdown-timer';
import msFormatter from './ms-formatter';

window.LoginGov = (window.LoginGov || {});
const LoginGov = window.LoginGov;
const documentElement = window.document.documentElement;

documentElement.className = documentElement.className.replace(/no-js/, '');

LoginGov.autoLogout = autoLogout;
LoginGov.countdownTimer = countdownTimer;
LoginGov.msFormatter = msFormatter;
