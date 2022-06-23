import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { AnalyticsContext } from '@18f/identity-document-capture';
import Warning from '@18f/identity-document-capture/components/warning';
import { TroubleshootingOptions } from '@18f/identity-components';
import { render } from '../../../support/document-capture';

describe('document-capture/components/warning', () => {
  it('renders a warning', async () => {
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
              options={[{ text: 'Get help', url: '/' }]}
            />
          }
          location="example"
        >
          Something went wrong
        </Warning>
      </AnalyticsContext.Provider>,
    );

    expect(addPageAction).to.have.been.calledWith('IdV: warning shown', {
      location: 'example',
      remaining_attempts: undefined,
    });

    const tryAgainButton = getByRole('button', { name: 'Try again' });
    await userEvent.click(tryAgainButton);

    expect(getByRole('heading', { name: 'Oops!' })).to.exist();
    expect(tryAgainButton).to.exist();
    expect(actionOnClick).to.have.been.calledOnce();
    expect(addPageAction).to.have.been.calledWith('IdV: warning action triggered', {
      location: 'example',
    });
    expect(getByText('Something went wrong')).to.exist();
    expect(getByRole('heading', { name: 'Having trouble?' })).to.exist();
    expect(getByRole('link', { name: 'Get help' }).getAttribute('href')).to.equal('/');
  });
});
