import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { addSearchParams } from '@18f/identity-url';
import { Button } from '@18f/identity-components';
import FlowContext from './context/flow-context';

function Cancel() {
  const { currentStep: step, cancelURL } = useContext(FlowContext);
  const { t } = useI18n();

  return (
    <Button href={addSearchParams(cancelURL, { step })} isUnstyled>
      {t('links.cancel')}
    </Button>
  );
}

export default Cancel;
