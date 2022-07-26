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
        addressLine2=""
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
        addressLine2="City, State 12345-1234"
        handleSelect={onClick}
        weekdayHours="9 AM - 5 PM"
        saturdayHours="9 AM - 6 PM"
        selectId={0}
        sundayHours="Closed"
      />,
    );

    const name = getByText('123 Test Address').parentElement!;
    expect(name.textContent).to.contain('test name');
    const streetAddress = getByText('123 Test Address').parentElement!;
    expect(streetAddress.textContent).to.contain('123 Test Address');
    const addressLine2 = getByText('123 Test Address').parentElement!;
    expect(addressLine2.textContent).to.contain('City, State 12345-1234');
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
});
