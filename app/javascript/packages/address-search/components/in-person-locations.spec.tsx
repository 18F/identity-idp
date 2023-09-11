import { render } from '@testing-library/react';
import { screen } from '@testing-library/dom';
import sinon from 'sinon';
import { Alert } from '@18f/identity-components';
import InPersonLocations from './in-person-locations';
import type { FormattedLocation } from './in-person-locations';


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

    context('Alert', () => {
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
            NoInPersonLocations={NoLocationsViewMock}
          />,
        );
    
        // the alert text
        expect(getByText(alertText)).to.exist();
      });
    
      it('renders results instructions when onSelect is passed', () => {
        const { getByText } = render(
          <InPersonLocations address={address} locations={locations} onSelect={onSelect} NoInPersonLocations={NoLocationsViewMock} />,
        );
    
        expect(getByText('in_person_proofing.body.location.po_search.results_instructions')).to.exist();
      });
    
      it('does not render results instructions when onSelect is not passed', () => {
        const { queryByText } = render(
          <InPersonLocations address={address} locations={locations} onSelect={null} NoInPersonLocations={NoLocationsViewMock} />,
        );
    
        expect(
          queryByText('in_person_proofing.body.location.po_search.results_instructions'),
        ).to.not.exist();
      });
    });
  });
  

});
