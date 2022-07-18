import { render } from '@testing-library/react';
import LocationCollectionItem from './location-collection-item';

describe('LocationCollectionItem', () => {
  it('renders the component with expected class and children', () => {
    const { container } = render(
      <LocationCollectionItem
        name={''}
        streetAddress={''}
        addressLine2={''}
        weekdayHours={''}
        saturdayHours={''}
        sundayHours=""
      />,
    );

    const wrapper = container.firstElementChild!;
    expect(wrapper.classList.contains('location-collection-item')).to.be.true();
    const locationCollectionItem = wrapper.firstElementChild!;
    expect(locationCollectionItem.classList.contains('usa-collection__body')).to.be.true();
  });

  // test btn has expected text
  // test heading is correct
  // test hours strings is correct
});
