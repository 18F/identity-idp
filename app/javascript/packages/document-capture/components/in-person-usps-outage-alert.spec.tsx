import { render } from '@testing-library/react';
import InPersonUspsOutageAlert from './in-person-usps-outage-alert';

describe('InPersonUspsOutageAlert', () => {
  let getByText;
  beforeEach(() => {
    getByText = render(<InPersonUspsOutageAlert />).getByText;
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
