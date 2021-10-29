import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import UploadContext from '../context/upload';
import ButtonTo from './button-to';

function StartOverOrCancel() {
  const { flowPath, startOverURL, cancelURL } = useContext(UploadContext);
  const { t } = useI18n();

  return (
    <div className="margin-top-4">
      {flowPath !== 'hybrid' && (
        <ButtonTo url={startOverURL} method="delete" isUnstyled>
          {t('doc_auth.buttons.start_over')}
        </ButtonTo>
      )}
      <div className="margin-top-2 padding-top-1 border-top border-primary-light">
        <a href={cancelURL}>{t('links.cancel')}</a>
      </div>
    </div>
  );
}

export default StartOverOrCancel;
