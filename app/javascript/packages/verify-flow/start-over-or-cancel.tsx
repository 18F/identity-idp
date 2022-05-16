import { useContext } from 'react';
import { ButtonTo } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import { addSearchParams } from '@18f/identity-url';
import FlowContext from './context/flow-context';

interface StartOverOrCancelProps {
  /**
   * Whether to show the option to start over.
   */
  canStartOver?: boolean;
}

function StartOverOrCancel({ canStartOver = true }: StartOverOrCancelProps) {
  const { currentStep: step, startOverURL, cancelURL } = useContext(FlowContext);
  const { t } = useI18n();

  return (
    <div className="margin-top-4">
      {canStartOver && (
        <ButtonTo url={addSearchParams(startOverURL, { step })} method="delete" isUnstyled>
          {t('doc_auth.buttons.start_over')}
        </ButtonTo>
      )}
      <div className="margin-top-2 padding-top-1 border-top border-primary-light">
        <a href={addSearchParams(cancelURL, { step })}>{t('links.cancel')}</a>
      </div>
    </div>
  );
}

export default StartOverOrCancel;
