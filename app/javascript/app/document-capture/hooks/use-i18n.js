import { useContext } from 'react';
import I18nContext from '../context/i18n';

function useI18n() {
  const strings = useContext(I18nContext);
  const t = (key) =>
    Object.prototype.hasOwnProperty.call(strings, key) ? strings[key] : key;
  return t;
}

export default useI18n;
