import { render } from '@testing-library/react';
import FlowContext from './context/flow-context';
import StartOverOrCancel from './start-over-or-cancel';

describe('StartOverOrCancel', () => {
  it('renders start over and cancel links', () => {
    const { queryByText } = render(<StartOverOrCancel />);

    expect(queryByText('doc_auth.buttons.start_over')).to.exist();
    expect(queryByText('links.cancel')).to.exist();
  });

  context('with excluded start over option', () => {
    it('renders only cancel link', () => {
      const { queryByText } = render(<StartOverOrCancel canStartOver={false} />);

      expect(queryByText('doc_auth.buttons.start_over')).to.not.exist();
      expect(queryByText('links.cancel')).to.exist();
    });
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
          <StartOverOrCancel />
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
