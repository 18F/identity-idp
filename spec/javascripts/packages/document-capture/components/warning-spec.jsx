import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { AnalyticsContext } from '@18f/identity-document-capture';
import Warning from '@18f/identity-document-capture/components/warning';
import { TroubleshootingOptions } from '@18f/identity-components';
import { render } from '../../../support/document-capture';

describe('document-capture/components/warning', () => {
  it('renders a warning', () => {
    const actionOnClick = sinon.spy();
    const addPageAction = sinon.spy();

    const { getByRole, getByText } = render(
      <AnalyticsContext.Provider value={{ addPageAction }}>
        <Warning
          heading="Oops!"
          actionText="Try again"
          actionOnClick={actionOnClick}
          troubleshootingHeading="Having trouble?"
          troubleshootingOptions={
            <TroubleshootingOptions
              heading="Having trouble?"
              options={[{ text: 'Get help', url: 'https://example.com/' }]}
            />
          }
          location="example"
        >
          Something went wrong
        </Warning>
      </AnalyticsContext.Provider>,
    );

    expect(addPageAction).to.have.been.calledWith({
      label: 'IdV: warning shown',
      payload: { location: 'example', remaining_attempts: undefined },
    });

    const tryAgainButton = getByRole('button', { name: 'Try again' });
    userEvent.click(tryAgainButton);

    expect(getByRole('heading', { name: 'Oops!' })).to.exist();
    expect(tryAgainButton).to.exist();
    expect(actionOnClick).to.have.been.calledOnce();
    expect(addPageAction).to.have.been.calledWith({
      label: 'IdV: warning action triggered',
      payload: {
        location: 'example',
      },
    });
    expect(getByText('Something went wrong')).to.exist();
    expect(getByRole('heading', { name: 'Having trouble?' })).to.exist();
    expect(getByRole('link', { name: 'Get help' }).href).to.equal('https://example.com/');
  });
});
