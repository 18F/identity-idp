import { t } from '@18f/identity-i18n';
import { render } from '@testing-library/react';
import SkipUspsFacilitiesApiErrorMessage from './skip-usps-facilities-api-error-message';

describe('SkipUspsFacilitiesApiErrorMessage', () => {
  it('renders the component with expected icon and text', async () => {
    const { findAllByText, getByAltText } = render(<SkipUspsFacilitiesApiErrorMessage />);

    // Empty location icon alt text needs translations
    const icon = getByAltText(
      t('in_person_proofing.body.location.po_search.usps_facilities_api_error_icon_alt_text'),
    );
    const errorHeader = await findAllByText(
      t('in_person_proofing.body.location.po_search.usps_facilities_api_error_header'),
    );
    const errorBody = await findAllByText(
      t('in_person_proofing.body.location.po_search.usps_facilities_api_error_body_html'),
    );

    expect(icon).to.exist();
    expect(errorHeader).to.exist();
    expect(errorBody).to.exist();
  });

  it('renders an NDS error alert in the NDS layout', () => {
    const { getByRole, queryByRole } = render(<SkipUspsFacilitiesApiErrorMessage nds />);

    const alert = getByRole('alert');
    expect(alert.classList.contains('usa-alert--error')).to.be.true();
    expect(
      getByRole('heading', {
        level: 2,
        name: 'in_person_proofing.body.location.po_search.usps_facilities_api_error_header',
      }),
    ).to.exist();
    expect(alert.querySelector('.usa-alert__text')!.textContent).to.equal(
      'in_person_proofing.body.location.po_search.usps_facilities_api_error_body_html',
    );
    expect(queryByRole('img')).not.to.exist();
  });
});
