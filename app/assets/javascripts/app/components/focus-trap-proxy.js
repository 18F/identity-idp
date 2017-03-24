/* eslint-disable */
import FocusTrap from 'focus-trap';
/* eslint-enable */

/* eslint-disable no-param-reassign */
function merge(target, ...sources) {
  return sources.reduce((memo, source) => {
    Object.keys(source).forEach((key) => {
      const prop = source[key];
      memo[key] = prop;
    });

    return memo;
  }, target);
}
/* eslint-disable no-param-reassign */

function FocusTrapProxy() {
  const NOOP = function() {};
  const focusables = [];

  return function makeTrap(el, options = {}) {
    const safeOnDeactivate = options.onDeactivate || NOOP;
    let lastActiveTrap = null;

    const focusTrapOptions = merge({}, options, {
      onDeactivate() {
        lastActiveTrap = this;

        safeOnDeactivate();
      },
    });

    const ownTrap = new FocusTrap(el, focusTrapOptions);

    focusables.push(ownTrap);

    return {
      activate() {
        focusables.forEach(trap => trap.deactivate());

        if (!lastActiveTrap) {
          lastActiveTrap = ownTrap;
        }

        return ownTrap.activate();
      },

      deactivate(opts = {}) {
        if (lastActiveTrap) lastActiveTrap.activate();
        lastActiveTrap = null;

        const deactivatedTrap = ownTrap.deactivate(opts);

        return deactivatedTrap;
      },

      pause() {
        ownTrap.pause();
      },
    };
  };
}

const focusTrapProxy = new FocusTrapProxy();

export default focusTrapProxy;
