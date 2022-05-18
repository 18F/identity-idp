import { render } from '@testing-library/react';
import { i18n } from '@18f/identity-i18n';
import { usePropertyValue } from '@18f/identity-test-helpers';
import VerifyFlowAlert from './verify-flow-alert';

describe('VerifyFlowAlert', () => {
  context('password confirm step', () => {
    context('with verified phone number', () => {
      usePropertyValue(i18n, 'strings', {
        'idv.messages.review.info_verified_html': 'We found records matching your %{phone_message}',
        'idv.messages.phone.phone_of_record': 'Phone of record',
      });

      it('renders status message', () => {
        const { getByRole } = render(
          <VerifyFlowAlert currentStep="password_confirm" values={{ phone: '5135551234' }} />,
        );

        expect(getByRole('status').querySelector('p')?.innerHTML).equal(
          'We found records matching your <strong>Phone of record</strong>',
        );
      });
    });

    context('with gpo verification', () => {
      it('renders nothing', () => {
        const { container } = render(<VerifyFlowAlert currentStep="password_confirm" />);

        expect(container.innerHTML).to.be.empty();
      });
    });
  });

  context('personal key step', () => {
    it('renders status message', () => {
      const { getByRole } = render(<VerifyFlowAlert currentStep="personal_key" />);

      expect(getByRole('status').textContent).equal('idv.messages.confirm');
    });
  });

  context('personal key confirm step', () => {
    it('renders status message', () => {
      const { getByRole } = render(<VerifyFlowAlert currentStep="personal_key_confirm" />);

      expect(getByRole('status').textContent).equal('idv.messages.confirm');
    });
  });

  context('step without a status message', () => {
    it('renders nothing', () => {
      const { container } = render(<VerifyFlowAlert currentStep="bad" />);

      expect(container.innerHTML).to.be.empty();
    });
  });
});
