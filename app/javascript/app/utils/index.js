import autoLogout from './auto-logout';
import countdownTimer from './countdown-timer';
import msFormatter from './ms-formatter';

window.LoginGov = window.LoginGov || {};
const { LoginGov } = window;

LoginGov.autoLogout = autoLogout;
LoginGov.countdownTimer = countdownTimer;
LoginGov.msFormatter = msFormatter;
