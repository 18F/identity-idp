/* eslint-disable */
import FocusTrap from 'focus-trap';
/* eslint-enable */

function merge(target, ...sources) {
  return sources.reduce((memo, source) => {
    for (const prop in source) {
      if (source.hasOwnProperty(prop)) {
        memo[prop] = source[prop];
      }
    }

    return memo;
  }, target);
}

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
        lastActiveTrap && lastActiveTrap.activate();
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
