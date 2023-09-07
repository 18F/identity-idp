import { render } from '@testing-library/react';
import InPersonLocationRedirectAlert from './in-person-location-redirect-alert';

describe('InPersonLocationRedirectAlert', () => {
  it('renders the expected content', () => {
    const infoAlertURL = 'https://example.com/';
    const { getByText, getByRole } = render(
      <InPersonLocationRedirectAlert infoAlertURL={infoAlertURL} />,
    );

    // the message
    expect(
      getByText('in_person_proofing.body.location.po_search.you_must_start.message'),
    ).to.exist();

    // the link text
    const linkText = 'in_person_proofing.body.location.po_search.you_must_start.link_text';
    expect(getByText(linkText)).to.exist();

    // the link href
    const link = getByRole('link') as HTMLAnchorElement;
    expect(link.href).to.equal(infoAlertURL);
  });
});
