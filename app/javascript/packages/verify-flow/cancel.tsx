import { useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { addSearchParams } from '@18f/identity-url';
import { PageFooter } from '@18f/identity-components';
import FlowContext from './context/flow-context';

function Cancel() {
  const { currentStep: step, cancelURL } = useContext(FlowContext);
  const { t } = useI18n();

  return (
    <PageFooter>
      <a href={addSearchParams(cancelURL, { step })}>{t('links.cancel')}</a>
    </PageFooter>
  );
}

export default Cancel;
