const root = window.LoginGov || {};

root.countdownTimer = (targetSelector, timeLeft = 0, interval = 1000) => {
  const countdownTarget = document.querySelector(targetSelector);

  if (!countdownTarget) return;

  (function tick() {
    countdownTarget.innerHTML = LoginGov.hmsFormatter(timeLeft);
    if (timeLeft <= 0) return;
    timeLeft -= interval;
    setTimeout(tick, interval);
  })();
};
