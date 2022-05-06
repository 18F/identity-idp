import { render } from '@testing-library/react';
import VerifyFlowAlert from './verify-flow-alert';

describe('VerifyFlowAlert', () => {
  context('step with a status message', () => {
    [
      ['personal_key', 'idv.messages.confirm'],
      ['personal_key_confirm', 'idv.messages.confirm'],
    ].forEach(([step, expected]) => {
      it('renders status message', () => {
        const { getByRole } = render(<VerifyFlowAlert currentStep={step} />);

        expect(getByRole('status').textContent).equal(expected);
      });
    });
  });

  context('step without a status message', () => {
    it('renders nothing', () => {
      const { container } = render(<VerifyFlowAlert currentStep="bad" />);

      expect(container.innerHTML).to.be.empty();
    });
  });
});
