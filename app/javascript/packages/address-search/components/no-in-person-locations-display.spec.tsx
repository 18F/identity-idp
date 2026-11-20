import { t } from '@18f/identity-i18n';
import { render } from '@testing-library/react';
import NoInPersonLocationsDisplay from './no-in-person-locations-display';

describe('NoInPersonLocationsDisplay', () => {
  it('renders the component with expected image and text', async () => {
    const { findAllByText, getByAltText } = render(
      <NoInPersonLocationsDisplay address="Somewhere over the rainbow" />,
    );

    const image = getByAltText(t('image_description.info_pin_map'));
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

  it('renders an NDS warning alert in the NDS layout', () => {
    const { getByRole, queryByRole } = render(
      <NoInPersonLocationsDisplay address="Somewhere over the rainbow" nds />,
    );

    const status = getByRole('status');
    expect(status.classList.contains('usa-alert--warning')).to.be.true();
    expect(
      getByRole('heading', {
        level: 2,
        name: 'in_person_proofing.body.location.po_search.none_found',
      }),
    ).to.exist();
    expect(status.textContent).to.contain(
      'in_person_proofing.body.location.po_search.none_found_tip',
    );
    expect(queryByRole('img')).not.to.exist();
  });
});
