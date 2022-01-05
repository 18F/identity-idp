import { createContext, useContext, useState, useEffect } from 'react';

/** @typedef {import('react').Dispatch<A>} Dispatch @template A */
/** @typedef {import('react').SetStateAction<S>} SetStateAction @template S */

/**
 * @typedef {Dispatch<SetStateAction<string|null>>[]} Subscribers
 */

const CookieSubscriberContext = createContext(/** @type {Map<string, Subscribers>} */ (new Map()));

/**
 * React hook to access and manage a cookie value by name.
 *
 * @param {string} name Cookie name.
 *
 * @return {[value: string|null, setValue: (nextValue: string?) => void]}
 */
function useCookie(name) {
  const getValue = () =>
    document.cookie
      .split(';')
      .map((part) => part.trim().split('='))
      .find(([key]) => key === name)?.[1] ?? null;

  const subscriptions = useContext(CookieSubscriberContext);
  const [value, setStateValue] = useState(getValue);

  useEffect(() => {
    if (!subscriptions.has(name)) {
      subscriptions.set(name, []);
    }

    const subscribers = /** @type {Subscribers} */ (subscriptions.get(name));
    subscribers.push(setStateValue);

    return () => {
      subscribers.splice(subscribers.indexOf(setStateValue), 1);
      if (!subscribers.length) {
        subscriptions.delete(name);
      }
    };
  }, [name]);

  /**
   * @param {string?} nextValue Value to set, or null to delete the value.
   */
  function setValue(nextValue) {
    const cookieValue = nextValue === null ? '; Max-Age=0' : nextValue;
    document.cookie = `${name}=${cookieValue}`;
    const subscribers = /** @type {Subscribers} */ (subscriptions.get(name));
    subscribers.forEach((setSubscriberValue) => setSubscriberValue(getValue));
  }

  return [value, setValue];
}

export default useCookie;
