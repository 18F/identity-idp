import { render } from '@testing-library/react';
import { Provider as UploadContextProvider } from '../context/upload';
import StartOverOrCancel from './start-over-or-cancel';

describe('StartOverOrCancel', () => {
  it('omits start over link when in hybrid flow', () => {
    const { getByText } = render(
      <UploadContextProvider
        flowPath="hybrid"
        endpoint=""
        csrf=""
        method="POST"
        backgroundUploadURLs={{}}
      >
        <StartOverOrCancel />
      </UploadContextProvider>,
    );

    expect(() => getByText('doc_auth.buttons.start_over')).to.throw();
    expect(getByText('links.cancel')).to.be.ok();
  });
});
