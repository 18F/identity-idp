/**
 * Returns a key event handler that calls the given callback only when emitted for the desired keys.
 *
 * @template E
 *
 * @param {string[]} keys Keys to handle.
 * @param {import('react').KeyboardEventHandler<E>} callback
 *
 * @return {import('react').KeyboardEventHandler<E>}
 */
export function filterKeyEvents(keys, callback) {
  return function handleKeyEvent(event) {
    if (keys.includes(event.key)) {
      callback(event);
    }
  };
}

function useButtonRole() {
  /**
   * Creates a props object which invokes the given callback on an interpreted "click" event, for
   * clicks originating either from a pointer or from a keyboard.
   *
   * @param {import('react').ReactEventHandler} onClickCallback
   */
  function createButtonRoleProps(onClickCallback) {
    return {
      role: 'button',
      onClick: onClickCallback,
      onKeyDown: filterKeyEvents(['Enter', ' '], onClickCallback),
    };
  }

  return createButtonRoleProps;
}

export default useButtonRole;
