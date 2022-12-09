import { render } from '@testing-library/react';
import { t } from '@18f/identity-i18n';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';

describe('HybridDocCaptureWarning', () => {
  describe('without SP', () => {
    it('renders correct warning title', () => {
      const props = { serviceProviderName: null, appName: 'Login.gov' };
      const { getByRole } = render(<HybridDocCaptureWarning {...props}></HybridDocCaptureWarning>);
      const alertElement = getByRole('status');

      expect(alertElement.textContent).to.have.string(
        t('doc_auth_hybrid_flow_warning.explanation_non_sp_html'),
      );
    });
  });
});
