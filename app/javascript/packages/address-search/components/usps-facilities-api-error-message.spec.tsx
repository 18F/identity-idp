import { t } from '@18f/identity-i18n';
import { render } from '@testing-library/react';
import UspsFacilitiesApiErrorMessage from './usps-facilities-api-error-message';

describe('UspsFacilitiesApiErrorMessage', () => {
  it('renders the component with expected icon and text', async () => {
    const { findAllByText, getByAltText } = render(
      <UspsFacilitiesApiErrorMessage />
    );

    // Empty location icon alt text needs translations
    const image = getByAltText('empty location icon');
    const errorHeader = await findAllByText(
      t('in_person_proofing.body.location.po_search.usps_facilities_api_error_header')
    );
    const errorBody = await findAllByText(
      'in_person_proofing.body.location.po_search.none_found_tip',
    );

    expect(image).to.exist();
    expect(errorHeader).to.exist();
    expect(errorBody).to.exist();
  });
});
