import useI18n from '../hooks/use-i18n';

function DocumentCapture() {
  const t = useI18n();

  return t('doc_auth.headings.welcome');
}

export default DocumentCapture;
