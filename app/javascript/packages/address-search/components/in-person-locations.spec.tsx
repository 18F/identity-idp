import { render } from '@testing-library/react';
import type { FormattedLocation } from './in-person-locations';
import InPersonLocations from './in-person-locations';

describe('InPersonLocations', () => {
  const locations: FormattedLocation[] = [
    {
      formattedCityStateZip: 'one',
      distance: 'one',
      id: 1,
      name: 'one',
      saturdayHours: 'one',
      streetAddress: 'one',
      sundayHours: 'one',
      weekdayHours: 'one',
      isPilot: false,
    },
    {
      formattedCityStateZip: 'two',
      distance: 'two',
      id: 2,
      name: 'two',
      saturdayHours: 'two',
      streetAddress: 'two',
      sundayHours: 'two',
      weekdayHours: 'two',
      isPilot: false,
    },
  ];

  const onSelect = () => {};

  const address = '123 Fake St, Hollywood, CA 90210';

  it('renders the info alert when a URL is passed', () => {
    const url = 'https://example.com/';

    const { getByRole, getByText } = render(
      <InPersonLocations
        address={address}
        infoAlertURL={url}
        locations={locations}
        onSelect={onSelect}
      />,
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
    expect(link.href).to.equal(url);
  });

  it('does not render the info alert when no URL is passed', () => {
    const { queryByText } = render(
      <InPersonLocations address={address} locations={locations} onSelect={onSelect} />,
    );

    // the message
    expect(
      queryByText('in_person_proofing.body.location.po_search.you_must_start.message'),
    ).to.not.exist();

    // the link text
    const linkText = 'in_person_proofing.body.location.po_search.you_must_start.link_text';
    expect(queryByText(linkText)).to.not.exist();
  });
});
