import { render } from '@testing-library/react';
import LocationCollection from './location-collection';

describe('LocationCollection', () => {
  it('renders the component with expected class and children', () => {
    const { getByText } = render(
      <LocationCollection>
        <div>LCI</div>
      </LocationCollection>,
    );

    const child = getByText('LCI');
    const item = child.parentElement!;

    expect(item.classList.contains('usa-collection')).to.be.true();
    expect(item.textContent).to.equal('LCI');
  });

  it('renders the component with custom class', () => {
    const { getByText } = render(
      <LocationCollection className="custom-class">
        <div>LCI</div>
      </LocationCollection>,
    );

    const child = getByText('LCI');
    const item = child.parentElement!;

    expect(item.classList.contains('custom-class')).to.be.true();
  });
});
