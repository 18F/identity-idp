import { render } from '@testing-library/react';
import { Alert } from '@18f/identity-components';
import { screen } from '@testing-library/dom';
import sinon from 'sinon';
import type { FormattedLocation } from './in-person-locations';
import InPersonLocations from './in-person-locations';

function NoLocationsViewMock({ address }) {
  return (
    <div data-testid="no-results-found">
      <p>No PO found</p>
      <p>{address}</p>
    </div>
  );
}

describe('InPersonLocations', () => {
  const locations: FormattedLocation[] = [
    {
      name: 'test name',
      streetAddress: '123 Test Address',
      formattedCityStateZip: 'City, State 12345-1234',
      distance: '0.2 miles',
      weekdayHours: '9 AM - 5 PM',
      saturdayHours: '9 AM - 6 PM',
      sundayHours: 'Closed',
      id: 1,
      isPilot: false,
    },
    {
      name: 'test name',
      streetAddress: '456 Test Address',
      formattedCityStateZip: 'City, State 12345-1234',
      distance: '2.1 miles',
      weekdayHours: '8 AM - 5 PM',
      saturdayHours: '10 AM - 5 PM',
      sundayHours: 'Closed',
      id: 1,
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
        noInPersonLocationsDisplay={NoLocationsViewMock}
      />,
    );

    // the alert text
    expect(getByText(alertText)).to.exist();
  });

  it('renders results instructions when onSelect is passed', () => {
    const { getByText } = render(
      <InPersonLocations
        address={address}
        locations={locations}
        onSelect={onSelect}
        noInPersonLocationsDisplay={NoLocationsViewMock}
      />,
    );

    expect(getByText('in_person_proofing.body.location.po_search.results_instructions')).to.exist();
  });

  it('does not render results instructions when onSelect is not passed', () => {
    const { queryByText } = render(
      <InPersonLocations
        address={address}
        locations={locations}
        onSelect={null}
        noInPersonLocationsDisplay={NoLocationsViewMock}
      />,
    );

    expect(
      queryByText('in_person_proofing.body.location.po_search.results_instructions'),
    ).to.not.exist();
  });

  context('when no locations are found', () => {
    it('renders the passed in noLocations component w/ address', () => {
      const onClick = sinon.stub();
      const { getByText } = render(
        <InPersonLocations
          locations={[]}
          onSelect={onClick}
          address={address}
          noInPersonLocationsDisplay={NoLocationsViewMock}
        />,
      );

      expect(getByText('No PO found')).to.exist();
      expect(getByText(address)).to.exist();
      expect(screen.getByTestId('no-results-found')).to.exist();
    });

    it('does not render Post Office results', () => {
      const onClick = sinon.stub();
      const { queryByText } = render(
        <InPersonLocations
          locations={[]}
          onSelect={onClick}
          address={address}
          noInPersonLocationsDisplay={NoLocationsViewMock}
        />,
      );

      expect(queryByText('in_person_proofing.body.location.po_search.results_instructions')).to.be
        .null;
      expect(queryByText('in_person_proofing.body.location.retail_hours_heading')).not.to.exist();
    });
  });

  context('when at least 1 location is found', () => {
    it('renders a list of Post Offices and does not render the passed in noInPersonLocationsDisplay component', () => {
      const onClick = sinon.stub();
      const { queryByText } = render(
        <InPersonLocations
          locations={locations}
          onSelect={onClick}
          address={address}
          noInPersonLocationsDisplay={NoLocationsViewMock}
        />,
      );

      expect(queryByText('123 Test Address')).to.exist();
      expect(queryByText('456 Test Address')).to.exist();
      expect(queryByText('No PO found')).to.be.null;
    });
  });
});
