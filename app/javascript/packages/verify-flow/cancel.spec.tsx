import { render } from '@testing-library/react';
import FlowContext from './context/flow-context';
import Cancel from './cancel';

describe('Cancel', () => {
  it('renders cancel link', () => {
    const { queryByText } = render(<Cancel />);

    expect(queryByText('links.cancel')).to.exist();
  });

  context('with flow context', () => {
    it('renders links with current step', () => {
      const { getByText } = render(
        <FlowContext.Provider
          value={{
            cancelURL: 'http://example.test/cancel',
            currentStep: 'one',
          }}
        >
          <Cancel />
        </FlowContext.Provider>,
      );

      const cancelLink = getByText('links.cancel') as HTMLAnchorElement;
      expect(cancelLink.getAttribute('href')).to.equal('http://example.test/cancel?step=one');
    });
  });
});
