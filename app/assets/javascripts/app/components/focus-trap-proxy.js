import focusTrap from 'focus-trap';

function FocusTrapProxy() {
  const NOOP = function() {};
  const focusables = [];

  return function trap(el, options) {
    const safeOnDeactivate = options.onDeactivate || NOOP;

    let ownTrap;
    let lastActiveTrap = null;

    options = Object.assign(options, {
      onDeactivate() {
        lastActiveTrap = this;

        safeOnDeactivate();
      }
    });

    ownTrap = new focusTrap(el, options)

    focusables.push(ownTrap);

    return {
      activate() {
        focusables.forEach(trap => trap.deactivate());

        if (!lastActiveTrap) {
          lastActiveTrap = ownTrap;
        }

        return ownTrap.activate();
      },

      deactivate(options = {}) {
        lastActiveTrap && lastActiveTrap.activate();
        lastActiveTrap = null;

        const deactivatedTrap = ownTrap.deactivate(options);

        return deactivatedTrap;
      },

      pause() {
        ownTrap.pause();
      }
    };
  };
}

export const focusTrapProxy = new FocusTrapProxy();
