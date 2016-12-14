import msFormatter from './ms-formatter';

export default (el, timeLeft = 0, interval = 1000) => {
  let remaining = timeLeft;

  if (!el || !('innerHTML' in el)) return;

  (function tick() {
    /* eslint-disable no-param-reassign */
    el.innerHTML = msFormatter(remaining);

    if (remaining <= 0) {
      return;
    }

    remaining -= interval;
    setTimeout(tick, interval);
  }());
};
