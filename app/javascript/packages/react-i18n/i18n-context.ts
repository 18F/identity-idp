import { createContext } from 'react';
import { i18n } from '@18f/identity-i18n';

const I18nContext = createContext(i18n);

I18nContext.displayName = 'I18nContext';

export default I18nContext;
