import { useContext } from 'react';
import formatHTML from './format-html';
import I18nContext from './i18n-context';

function useI18n() {
  const { t } = useContext(I18nContext);

  return { t, formatHTML };
}

export default useI18n;
