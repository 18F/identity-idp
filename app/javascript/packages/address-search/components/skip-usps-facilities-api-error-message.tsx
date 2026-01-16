import { getAssetPath } from '@18f/identity-assets';
import { useI18n } from '@18f/identity-react-i18n';
import { Link } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';

const helpCenterUrl =
  'https://login.gov/help/verify-your-identity/verify-your-identity-in-person/find-a-participating-post-office';

export default function SkipUspsFacilitiesApiErrorMessage() {
  const { formatHTML } = useI18n();

  const translatedErrorBody = t(
    'in_person_proofing.body.location.po_search.usps_facilities_api_error_body_html',
    { link_url: helpCenterUrl },
  );

  function formatErrorBody() {
    return formatHTML(translatedErrorBody, {
      a: () => (
        <Link href={helpCenterUrl} isExternal>
          {t(
            'in_person_proofing.body.location.po_search.usps_facilities_api_error_help_center_text',
          )}
        </Link>
      ),
    });
  }

  return (
    <div className="usps-facilities-api-error grid-row">
      <div className="usps-facilities-api-error__svg grid-col-12 tablet:grid-col-auto">
        <img
          alt={t(
            'in_person_proofing.body.location.po_search.usps_facilities_api_error_icon_alt_text',
          )}
          className="margin-right-2"
          width={65}
          height={65}
          src={getAssetPath('empty-loc.svg')}
        />
      </div>
      <div className="usps-facilities-api-error__text grid-col-12 tablet:grid-col-fill">
        <h2 className="usps-facilities-api-error__header margin-top-0">
          {t('in_person_proofing.body.location.po_search.usps_facilities_api_error_header')}
        </h2>
        <p className="usps-facilities-api-error__body margin-y-0">{formatErrorBody()}</p>
      </div>
    </div>
  );
}
