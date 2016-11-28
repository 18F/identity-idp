const root = window.LoginGov = (window.LoginGov || {});

root.countdownTimer = (targetSelector, timeLeft = 0, interval = 1000) => {
  const countdownTarget = document.querySelector(targetSelector);
  let remaining = timeLeft;

  if (!countdownTarget) return;

  (function tick() {
    countdownTarget.innerHTML = window.LoginGov.hmsFormatter(remaining);

    if (remaining <= 0) {
      window.LoginGov.autoLogout();
      return;
    }

    remaining -= interval;
    setTimeout(tick, interval);
  }());
};
