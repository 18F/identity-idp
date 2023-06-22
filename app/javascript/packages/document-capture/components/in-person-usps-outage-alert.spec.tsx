import { render } from '@testing-library/react';
import InPersonOutageAlert from './in-person-outage-alert';

describe('InPersonOutageAlert', () => {
  let getByText;
  beforeEach(() => {
    getByText = render(<InPersonOutageAlert />).getByText;
  });

  it('renders the title', () => {
    expect(
      getByText('idv.failure.exceptions.in_person_outage_error_message.post_cta.title'),
    ).to.exist();
  });

  it('renders the body', () => {
    expect(
      getByText('idv.failure.exceptions.in_person_outage_error_message.post_cta.body'),
    ).to.exist();
  });
});
