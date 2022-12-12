import { render } from '@testing-library/react';
import { t } from '@18f/identity-i18n';
import HybridDocCaptureWarning from './hybrid-doc-capture-warning';

describe('HybridDocCaptureWarning', () => {
  describe('without SP', () => {
    it('renders correct warning title', () => {
      const props = { serviceProviderName: null, appName: 'Login.gov' };
      const { getByRole } = render(<HybridDocCaptureWarning {...props} />);
      const alertElement = getByRole('status');

      expect(alertElement.textContent).to.have.string(
        t('doc_auth.hybrid_flow_warning.explanation_non_sp_html'),
      );
    });

    it('does not render a third list item pertaining to SP services', () => {
      const props = { serviceProviderName: null, appName: 'Login.gov' };
      const { getByRole } = render(<HybridDocCaptureWarning {...props} />);
      const alertElement = getByRole('status');
      const notExpectedString = t('doc_auth.hybrid_flow_warning.only_add_sp_services_html').replace(
        '%{serviceProviderName}',
        props.serviceProviderName,
      );

      expect(alertElement.textContent).to.not.have.string(notExpectedString);
    });
  });

  describe('with SP', () => {
    it('renders the correct warning title', () => {
      const props = { serviceProviderName: 'Demo Service', appName: 'Login.gov' };
      const { getByRole } = render(<HybridDocCaptureWarning {...props} />);
      const alertElement = getByRole('status');
      const expectedString = t('doc_auth.hybrid_flow_warning.explanation_html')
        .replace('%{appName}', props.appName)
        .replace('%{serviceProviderName}', props.serviceProviderName);

      expect(alertElement.textContent).to.have.string(expectedString);
    });
    it('renders a third list item pertaining to SP services', () => {
      const props = { serviceProviderName: 'Demo Service', appName: 'Login.gov' };
      const { getByRole } = render(<HybridDocCaptureWarning {...props} />);
      const alertElement = getByRole('status');
      const expectedString = t('doc_auth.hybrid_flow_warning.only_add_sp_services_html').replace(
        '%{serviceProviderName}',
        props.serviceProviderName,
      );

      expect(alertElement.textContent).to.have.string(expectedString);
    });
  });
});
