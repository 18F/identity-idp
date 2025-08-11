import { createContext, useContext, useState, useEffect } from 'react';
import type { Dispatch, SetStateAction } from 'react';

type Subscribers = Dispatch<SetStateAction<string | null>>[];

const CookieSubscriberContext = createContext<Map<string, Subscribers>>(new Map());

function useCookie(name: string): [string | null, (nextValue: string | null) => void, () => void] {
  const getValue = (): string | null =>
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

    const subscribers = subscriptions.get(name)!;
    subscribers.push(setStateValue);

    return () => {
      subscribers.splice(subscribers.indexOf(setStateValue), 1);
      if (!subscribers.length) {
        subscriptions.delete(name);
      }
    };
  }, [name, subscriptions]);

  function refreshValue() {
    const nextValue = getValue();
    const subscribers = subscriptions.get(name)!;
    subscribers.forEach((setSubscriberValue) => setSubscriberValue(nextValue));
  }

  function setValue(nextValue: string | null) {
    const cookieValue = nextValue === null ? '; Max-Age=0' : nextValue;
    document.cookie = `${name}=${cookieValue}`;
    refreshValue();
  }

  return [value, setValue, refreshValue];
}

export default useCookie;
