const root = window.LoginGov || {};

root.countdownTimer = (targetSelector, timeLeft = 0, interval = 1000) => {
  const countdownTarget = document.querySelector(targetSelector);
  let remaining = timeLeft;

  if (!countdownTarget) return;

  (function tick() {
    countdownTarget.innerHTML = window.LoginGov.hmsFormatter(remaining);
    if (remaining <= 0) return;
    remaining -= interval;
    setTimeout(tick, interval);
  }());
};
