import { PageHeading, LocationCollectionItem, LocationCollection } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

function InPersonLocationStep() {
  const { t } = useI18n();

  const mockData = [
    {
      header: 'BALTIMORE — Post Office \u2122',
      addressLine1: '900 E FAYETTE ST RM 118',
      addressLine2: 'BALTIMORE, MD 21233-9715',
      hoursWD: '8:30 am-7:00 pm',
      hoursSat: '8:30 am-5:00 pm',
      hoursSun: 'Closed',
    },
    {
      header: 'BETHSEDA — Post Office \u2122',
      addressLine1: '6900 WISCONSIN AVE STE 100',
      addressLine2: 'CHEVY CHASE, MD 20815-9996',
      hoursWD: '9:00 am-5:00 pm',
      hoursSat: '9:00 am-4:00 pm',
      hoursSun: 'Closed',
    },
    {
      header: 'FRIENDSHIP — Post Office \u2122',
      addressLine1: '4005 WISCONSIN AVE NW',
      addressLine2: 'WASHINGTON, DC 20016-9997',
      hoursWD: '8:00 am-6:00 pm',
      hoursSat: '8:00 am-4:00 pm',
      hoursSun: '10:00 am-4:00 pm',
    },
    {
      header: 'WASHINGTON — Post Office \u2122',
      addressLine1: '900 BRENTWOOD RD NE',
      addressLine2: 'WASHINGTON, DC 20018-9997',
      hoursWD: '8:30 am-7:00 pm',
      hoursSat: '8:30 am-5:00 pm',
      hoursSun: 'Closed',
    },
  ];
  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.location')}</PageHeading>

      <p>{t('in_person_proofing.body.location.location_step_about')}</p>
      <LocationCollection>
        {mockData.map((item) => (
          <LocationCollectionItem
            header={item.header}
            addressLine1={item.addressLine1}
            addressLine2={item.addressLine2}
            hoursWD={item.hoursWD}
            hoursSat={item.hoursSat}
            hoursSun={item.hoursSun}
          />
        ))}
      </LocationCollection>
    </>
  );
}

export default InPersonLocationStep;
