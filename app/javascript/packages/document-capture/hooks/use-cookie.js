import useForceRender from './use-force-render';

/**
 * React hook to access and manage a cookie value by name.
 *
 * @param {string} name Cookie name.
 *
 * @return {[getValue: () => string|null, setValue: (nextValue: string?) => void]}
 */
function useCookie(name) {
  const forceRender = useForceRender();

  const getValue = () =>
    document.cookie
      .split(';')
      .map((part) => part.trim().split('='))
      .find(([key]) => key === name)?.[1] ?? null;

  /**
   * @param {string?} nextValue Value to set, or null to delete the value.
   */
  function setValue(nextValue) {
    const cookieValue = nextValue === null ? '; Max-Age=0' : nextValue;
    document.cookie = `${name}=${cookieValue}`;
    forceRender();
  }

  return [getValue, setValue];
}

export default useCookie;
