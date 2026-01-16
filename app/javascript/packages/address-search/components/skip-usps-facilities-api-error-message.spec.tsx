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
});
