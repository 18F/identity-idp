import autoLogout from './auto-logout';
import countdownTimer from './countdown-timer';
import msFormatter from './ms-formatter';

const LoginGov = window.LoginGov = (window.LoginGov || {});

LoginGov.autoLogout = autoLogout;
LoginGov.countdownTimer = countdownTimer;
LoginGov.msFormatter = msFormatter;
