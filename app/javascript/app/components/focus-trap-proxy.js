/* eslint-disable */
import FocusTrap from 'focus-trap';
/* eslint-enable */

function FocusTrapProxy() {
  const focusables = [];
  let activated = [];

  return function makeTrap(el, options = {}) {
    const ownTrap = new FocusTrap(el, options);

    focusables.push(ownTrap);

    return {
      activate() {
        focusables.forEach(trap => trap.deactivate());

        activated.push(ownTrap);

        ownTrap.activate();

        return ownTrap;
      },

      deactivate(opts = {}) {
        const deactivatedTrap = ownTrap.deactivate(opts);

        // `deactivate` will return a valid trap object if it is available to be
        // deactivated. If not, it returns a falsey value. If nothing was deactivated,
        // bail out.
        if (!deactivatedTrap) {
          return false;
        }

        activated = activated.filter(activatedTrap => activatedTrap !== ownTrap);

        if (activated.length) {
          activated[activated.length - 1].activate();
        }

        return deactivatedTrap;
      },

      pause() {
        ownTrap.pause();
      },
    };
  };
}

const focusTrapProxy = FocusTrapProxy.call(FocusTrapProxy);

export default focusTrapProxy;
