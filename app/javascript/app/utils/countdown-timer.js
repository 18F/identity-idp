const msFormatter = require('./ms-formatter').default;

export default (el, timeLeft = 0, endTime = null, interval = 1000) => {
  let remaining = timeLeft;
  let currentTime;
  let timer;

  if (!el || !('innerHTML' in el)) {
    return;
  }

  function tick() {
    /* eslint-disable no-param-reassign */
    if (endTime) {
      currentTime = new Date().getTime();
      remaining = endTime - currentTime;
    }

    el.childNodes[0].nodeValue = msFormatter(remaining);

    if (remaining <= 0) {
      clearInterval(timer);
      return;
    }

    remaining -= interval;
  }

  tick();
  timer = setInterval(tick, interval);
  return timer;
};
