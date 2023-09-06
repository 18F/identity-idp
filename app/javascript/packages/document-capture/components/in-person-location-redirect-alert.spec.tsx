import { render } from '@testing-library/react';
import InPersonLocationRedirectAlert from './in-person-location-redirect-alert';

describe('InPersonLocationRedirectAlert', () => {
  it('renders the expected content', () => {
    const { getByText } = render(<InPersonLocationRedirectAlert />);

    expect(
      getByText('in_person_proofing.body.location.po_search.you_must_start.message'),
    ).to.exist();

    expect(
      getByText('in_person_proofing.body.location.po_search.you_must_start.link_text'),
    ).to.exist();
  });
});
