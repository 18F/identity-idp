import { render } from '@testing-library/react';
import { screen } from '@testing-library/dom';
import sinon from 'sinon';
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
  context('when no locations are found', () => {
    it('renders the passed in noLocations component w/ address', () => {
      const onClick = sinon.stub();
      const { getByText } = render(
        <InPersonLocations
          locations={[]}
          onSelect={onClick}
          address="Somewhere over the rainbow"
          NoInPersonLocations={NoLocationsViewMock}
        />,
      );

      expect(getByText('No PO found')).to.exist();
      expect(getByText('Somewhere over the rainbow')).to.exist();
      expect(screen.getByTestId('no-results-found')).to.exist();
    });

    it('does not render Post Office results', () => {
      const onClick = sinon.stub();
      const { queryByText } = render(
        <InPersonLocations
          locations={[]}
          onSelect={onClick}
          address="Somewhere over the rainbow"
          NoInPersonLocations={NoLocationsViewMock}
        />,
      );

      expect(queryByText('in_person_proofing.body.location.po_search.results_instructions')).to.be
        .null;
      expect(queryByText('in_person_proofing.body.location.retail_hours_heading')).not.to.exist();
    });
  });

  context('when at least 1 location is found', () => {
    it('renders a list of Post Offices and does not render the passed in NoInPersonLocationss component', () => {
      const onClick = sinon.stub();
      const mockLocation = [
        {
          name: 'test name',
          streetAddress: '123 Test Address',
          formattedCityStateZip: 'City, State 12345-1234',
          distance: '0.2 miles',
          handleSelect: { onClick },
          weekdayHours: '9 AM - 5 PM',
          saturdayHours: '9 AM - 6 PM',
          selectId: '0',
          sundayHours: 'Closed',
          id: 1,
          isPilot: false,
        },
        {
          name: 'test name',
          streetAddress: '456 Test Address',
          formattedCityStateZip: 'City, State 12345-1234',
          distance: '2.1 miles',
          handleSelect: { onClick },
          weekdayHours: '8 AM - 5 PM',
          saturdayHours: '10 AM - 5 PM',
          selectId: '0',
          sundayHours: 'Closed',
          id: 1,
          isPilot: false,
        },
      ];

      const { queryByText } = render(
        <InPersonLocations
          locations={mockLocation}
          onSelect={onClick}
          address="Somewhere over the rainbow"
          NoInPersonLocations={NoLocationsViewMock}
        />,
      );

      expect(queryByText('123 Test Address')).to.exist();
      expect(queryByText('456 Test Address')).to.exist();
      expect(queryByText('No PO found')).to.be.null;
    });
  });
});