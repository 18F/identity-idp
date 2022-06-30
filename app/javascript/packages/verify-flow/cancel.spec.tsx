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
      const { getByText, baseElement } = render(
        <FlowContext.Provider
          value={{
            startOverURL: 'http://example.test/start-over',
            cancelURL: 'http://example.test/cancel',
            currentStep: 'one',
            basePath: '',
            inPersonURL: null,
            onComplete() {},
          }}
        >
          <Cancel />
        </FlowContext.Provider>,
      );

      const startOverForm = baseElement.querySelector('form')!;
      const cancelLink = getByText('links.cancel') as HTMLAnchorElement;

      expect(startOverForm.getAttribute('action')).to.equal(
        'http://example.test/start-over?step=one',
      );
      expect(cancelLink.getAttribute('href')).to.equal('http://example.test/cancel?step=one');
    });
  });
});
