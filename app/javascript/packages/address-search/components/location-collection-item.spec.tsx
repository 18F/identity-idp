import { render } from '@testing-library/react';
import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
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
    expect(display.classList.contains('grid-row')).to.be.true();
    const column = display.firstElementChild!;
    expect(column.classList.contains('grid-col-fill')).to.be.true();
    const heading = column.firstElementChild!;
    expect(heading.classList.contains('usa-collection__heading')).to.be.true();
    expect(heading.classList.contains('margin-bottom-1')).to.be.true();
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

  context('when handleSelect callback is not provided', () => {
    it('renders the component without the button', () => {
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

      expect(container.textContent).to.contain('in_person_proofing.body.location.location_button');
    });
  });

  context('when handleSelect callback is provided', () => {
    it('renders the component with the button', () => {
      const { container } = render(
        <LocationCollectionItem
          name=""
          streetAddress=""
          formattedCityStateZip=""
          weekdayHours=""
          saturdayHours=""
          selectId={0}
          sundayHours=""
        />,
      );

      expect(container.textContent).to.not.contain(
        'in_person_proofing.body.location.location_button',
      );
    });
  });

  context('in the NDS layout', () => {
    function renderNDS(props = {}) {
      return render(
        <LocationCollectionItem
          name="test name"
          distance="2.4 miles"
          streetAddress="4163 E Camelback Road"
          formattedCityStateZip="Phoenix, AZ, 85017-8993"
          handleSelect={sinon.stub()}
          weekdayHours="9:00 AM - 12:00 PM"
          saturdayHours="8:30 AM - 5:00 PM"
          selectId={3}
          sundayHours="Closed"
          nds
          {...props}
        />,
      );
    }

    it('renders the DS location item with the distance, address and NDS hours copy', () => {
      const { container, getByRole, getByText } = renderNDS();

      const item = container.querySelector('li.location-collection__item')!;
      expect(item).to.exist();
      expect(
        getByRole('heading', {
          level: 3,
          name: 'in_person_proofing.body.location.distance',
        }).classList.contains('location-collection__distance'),
      ).to.be.true();
      expect(item.querySelector('.location-collection__address')!.textContent).to.equal(
        '4163 E Camelback RoadPhoenix, AZ, 85017-8993',
      );
      expect(getByRole('heading', { level: 4, name: 'nds.post_office.search.hours' })).to.exist();
      expect(
        getByText('in_person_proofing.body.location.retail_hours_weekday 9:00 AM - 12:00 PM'),
      ).to.exist();
      expect(getByText('nds.post_office.search.saturday 8:30 AM - 5:00 PM')).to.exist();
      expect(getByText('nds.post_office.search.sunday Closed')).to.exist();
      expect(item.querySelector('.usa-collection__body')).not.to.exist();
    });

    it('renders the inline Select from tablet up and the full-width Select on mobile', async () => {
      const handleSelect = sinon.stub();
      const { container } = renderNDS({ handleSelect });

      const desktop = container.querySelector(
        '.location-collection__top > .display-none.tablet\\:display-block button',
      )!;
      const mobile = container.querySelector('li > .tablet\\:display-none button')!;
      expect(desktop.classList.contains('usa-button--md')).to.be.true();
      expect(mobile.classList.contains('width-full')).to.be.true();

      await userEvent.click(mobile);
      expect(handleSelect).to.have.been.calledWith(sinon.match.any, 3);
    });

    it('shows the name when there is no distance and omits Select without a handler', () => {
      const { getByRole, queryByRole } = renderNDS({
        distance: undefined,
        handleSelect: undefined,
      });

      expect(getByRole('heading', { level: 3, name: 'test name' })).to.exist();
      expect(queryByRole('button')).not.to.exist();
    });
  });
});
