/**
 * Returns true if an invocation of the given function does not throw an error, or false otherwise.
 *
 * @param {() => any} fn Function to invoke.
 *
 * @return {boolean}
 */
function isSafe(fn) {
  try {
    fn();
    return true;
  } catch {
    return false;
  }
}

export default isSafe;
