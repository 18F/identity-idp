import { getAssetPath } from '@18f/identity-assets';
import { t } from '@18f/identity-i18n';

interface NoInPersonLocationsDisplayProps {
  address: string;
  nds?: boolean;
}

function NoInPersonLocationsDisplay({ address, nds = false }: NoInPersonLocationsDisplayProps) {
  if (nds) {
    return (
      <div className="usa-alert usa-alert--warning text-left" role="status">
        <div className="usa-alert__body">
          <h2 className="usa-alert__heading">
            {t('in_person_proofing.body.location.po_search.none_found', { address })}
          </h2>
          <p className="usa-alert__text">
            {t('in_person_proofing.body.location.po_search.none_found_tip')}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="grid-row grid-gap grid-gap-1">
      <img
        className="grid-col-2 margin-top-3"
        alt={t('image_description.info_pin_map')}
        width={65}
        height={65}
        src={getAssetPath('info-pin-map.svg')}
      />
      <div className="inline-block grid-col-10">
        <h2 role="status">
          {t('in_person_proofing.body.location.po_search.none_found', { address })}
        </h2>
        <p>{t('in_person_proofing.body.location.po_search.none_found_tip')}</p>
      </div>
    </div>
  );
}

export default NoInPersonLocationsDisplay;
