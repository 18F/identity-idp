import { render } from '@testing-library/react';
import sinon from 'sinon';
import LocationCollectionItem from './location-collection-item';

describe('LocationCollectionItem', () => {
  it('renders the component with expected class and children', () => {
    const onClick = sinon.stub();
    const { container } = render(
      <LocationCollectionItem
        name=""
        streetAddress=""
        formattedCityStateZip=""
        handleSelect={onClick}
        weekdayHours=""
        saturdayHours=""
        selectId={0}
        sundayHours=""
      />,
    );

    const wrapper = container.firstElementChild!;
    expect(wrapper.classList.contains('location-collection-item')).to.be.true();
    const locationCollectionItem = wrapper.firstElementChild!;
    expect(locationCollectionItem.classList.contains('usa-collection__body')).to.be.true();
    const display = locationCollectionItem.firstElementChild!;
    expect(display.classList.contains('display-flex')).to.be.true();
    expect(display.classList.contains('flex-justify')).to.be.true();
    const heading = display.firstElementChild!;
    expect(heading.classList.contains('usa-collection__heading')).to.be.true();
  });

  it('renders the component with expected data', () => {
    const onClick = sinon.stub();
    const { getByText } = render(
      <LocationCollectionItem
        name="test name"
        streetAddress="123 Test Address"
        formattedCityStateZip="City, State 12345-1234"
        handleSelect={onClick}
        weekdayHours="9 AM - 5 PM"
        saturdayHours="9 AM - 6 PM"
        selectId={0}
        sundayHours="Closed"
      />,
    );

    const addressParent = getByText('123 Test Address').parentElement!;
    expect(addressParent.textContent).to.contain('test name');
    expect(addressParent.textContent).to.contain('123 Test Address');
    expect(addressParent.textContent).to.contain('City, State 12345-1234');
    const wkDayHours = getByText(
      'in_person_proofing.body.location.retail_hours_weekday 9 AM - 5 PM',
    ).parentElement!;
    expect(wkDayHours.textContent).to.contain('9 AM - 5 PM');
    const satHours = getByText('in_person_proofing.body.location.retail_hours_sat 9 AM - 6 PM')
      .parentElement!;
    expect(satHours.textContent).to.contain('9 AM - 6 PM');
    const sunHours = getByText('in_person_proofing.body.location.retail_hours_sun Closed')
      .parentElement!;
    expect(sunHours.textContent).to.contain('Closed');
  });

  it('renders the component that includes contact information with expected data', () => {
    const onClick = sinon.stub();
    const { getByText } = render(
      <LocationCollectionItem
        distance="1.0 mi"
        phone="555-123-4567"
        tty="222-222-2222"
        name=""
        streetAddress="123 Test Address"
        formattedCityStateZip=""
        handleSelect={onClick}
        weekdayHours=""
        saturdayHours=""
        selectId={0}
        sundayHours=""
      />,
    );

    const addressParent = getByText('123 Test Address').parentElement!;
    expect(addressParent.textContent).to.contain('in_person_proofing.body.location.distance');
    expect(addressParent.textContent).to.contain('555-123-4567');
    expect(addressParent.textContent).to.contain('222-222-2222');
  });

  context('when no retail hours are known', () => {
    it('does not display any retail hours', () => {
      const onClick = sinon.stub();
      const { queryByText } = render(
        <LocationCollectionItem
          name="test name"
          streetAddress="123 Test Address"
          formattedCityStateZip="City, State 12345-1234"
          handleSelect={onClick}
          selectId={0}
          weekdayHours=""
          saturdayHours=""
          sundayHours=""
        />,
      );

      const heading = queryByText('in_person_proofing.body.location.retail_hours_heading');
      expect(heading).not.to.exist();
      const wkDayHours = queryByText('in_person_proofing.body.location.retail_hours_weekday', {
        exact: false,
      });
      expect(wkDayHours).not.to.exist();
      const satHours = queryByText('in_person_proofing.body.location.retail_hours_sat', {
        exact: false,
      });
      expect(satHours).not.to.exist();
      const sunHours = queryByText('in_person_proofing.body.location.retail_hours_sun', {
        exact: false,
      });
      expect(sunHours).not.to.exist();
    });
  });

  context('when some retail hours are known', () => {
    it('displays the known retail hours', () => {
      const onClick = sinon.stub();
      const { queryByText } = render(
        <LocationCollectionItem
          name="test name"
          streetAddress="123 Test Address"
          formattedCityStateZip="City, State 12345-1234"
          handleSelect={onClick}
          selectId={0}
          weekdayHours="9 AM - 5 PM"
          saturdayHours=""
          sundayHours=""
        />,
      );

      const heading = queryByText('in_person_proofing.body.location.retail_hours_heading');
      expect(heading).to.exist();
      const wkDayHours = queryByText(
        'in_person_proofing.body.location.retail_hours_weekday 9 AM - 5 PM',
      );
      expect(wkDayHours).to.exist();
      const satHours = queryByText('in_person_proofing.body.location.retail_hours_sat', {
        exact: false,
      });
      expect(satHours).not.to.exist();
      const sunHours = queryByText('in_person_proofing.body.location.retail_hours_sun', {
        exact: false,
      });
      expect(sunHours).not.to.exist();
    });
  });
});
