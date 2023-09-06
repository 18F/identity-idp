import { render } from '@testing-library/react';
import NoInPersonLocationsDisplay from './no-in-person-locations-display';

describe('NoInPersonLocationsDisplay', () => {
  it('renders the component with expected image and text', async () => {
    const { findAllByText, getByAltText } = render(
      <NoInPersonLocationsDisplay address="Somewhere over the rainbow" />,
    );

    const image = getByAltText('exclamation mark inside of map pin');
    const noneFoundMessage = await findAllByText(
      'in_person_proofing.body.location.po_search.none_found',
    );
    const noneFoundTipMessage = await findAllByText(
      'in_person_proofing.body.location.po_search.none_found_tip',
    );

    expect(image).to.exist();
    expect(noneFoundMessage).to.exist();
    expect(noneFoundTipMessage).to.exist();
  });
});
