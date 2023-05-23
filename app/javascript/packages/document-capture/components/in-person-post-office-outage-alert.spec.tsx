import { render } from '@testing-library/react';
import InPersonPostOfficeOutageAlert from './in-person-post-office-outage-alert';

describe('InPersonPostOfficeOutageAlert', () => {
  let getByText;
  beforeEach(() => {
    getByText = render(<InPersonPostOfficeOutageAlert />).getByText;
  });

  it('renders the title', () => {
    expect(
      getByText('idv.failure.exceptions.post_office_outage_error_message.post_cta.title'),
    ).to.exist();
  });

  it('renders the body', () => {
    expect(
      getByText('idv.failure.exceptions.post_office_outage_error_message.post_cta.body'),
    ).to.exist();
  });
});
