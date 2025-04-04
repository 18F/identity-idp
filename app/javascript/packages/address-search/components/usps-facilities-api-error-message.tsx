import { getAssetPath } from '@18f/identity-assets';
import { t } from '@18f/identity-i18n';

export default function UspsFacilitiesApiErrorMessage() {
  return (
    <div className="usps-facilities-api-error">
      <div className="usps-facilities-api-error__svg">
        <img src={getAssetPath("empty-loc.svg")} />
      </div>
      <div className="usps-facilities-api-error__text">
        <p className="usps-facilities-api-error__header">
          {t('in_person_proofing.body.location.po_search.usps_facilities_api_error_header')}
        </p>
        <p className="usps-facilities-api-error__body">
          {t('in_person_proofing.body.location.po_search.usps_facilities_api_error_body')}
        </p>
      </div>
    </div>
  );
}
