import { getAssetPath } from '@18f/identity-assets';
import { t } from '@18f/identity-i18n';

function PostOfficeNoResults({ address }) {
  return (
    <>
      <img
        className="grid-col-2 inline-block veritcal-align-top margin-top-22"
        style={{ display: 'inline-block', marginTop: '20px', verticalAlign: 'top' }}
        alt="exclamation mark inside of map pin"
        src={getAssetPath('info-pin-map.svg')}
      />
      <div className="grid-offset-1 grid-col-9 inline-block" style={{ display: 'inline-block' }}>
        <h3 role="status">
          {t('in_person_proofing.body.location.po_search.none_found', { address })}
        </h3>
        <p>{t('in_person_proofing.body.location.po_search.none_found_tip')}</p>
      </div>
    </>
  );
}

export default PostOfficeNoResults;
