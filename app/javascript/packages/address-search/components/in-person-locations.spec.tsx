import { render } from '@testing-library/react';
import { Alert } from '@18f/identity-components';
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

  it('renders a component at the top of results when passed', () => {
    const alertText = 'hello world';
    const alertComponent = () => <Alert>{alertText}</Alert>;

    const { getByText } = render(
      <InPersonLocations
        address={address}
        resultsHeaderComponent={alertComponent}
        locations={locations}
        onSelect={onSelect}
      />,
    );

    // the alert text
    expect(getByText(alertText)).to.exist();
  });

  it('renders results instructions when onSelect is passed', () => {
    const { getByText } = render(
      <InPersonLocations address={address} locations={locations} onSelect={onSelect} />,
    );

    expect(getByText('in_person_proofing.body.location.po_search.results_instructions')).to.exist();
  });

  it('does not render results instructions when onSelect is not passed', () => {
    const { queryByText } = render(
      <InPersonLocations address={address} locations={locations} onSelect={null} />,
    );

    expect(
      queryByText('in_person_proofing.body.location.po_search.results_instructions'),
    ).to.not.exist();
  });
});
