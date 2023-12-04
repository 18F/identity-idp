import { render } from '@testing-library/react';
import InPersonOutageAlert from './in-person-outage-alert';
import { InPersonContext } from '../context';

describe('InPersonOutageAlert', () => {
  let getByText;
  beforeEach(() => {
    getByText = render(
      <InPersonContext.Provider
        value={{
          locationsURL: 'https://localhost:3000/unused',
          addressSearchURL: 'https://localhost:3000/unused',
          inPersonOutageExpectedUpdateDate: 'January 1, 2024',
          inPersonOutageMessageEnabled: true,
          inPersonFullAddressEntryEnabled: false,
          optedInToInPersonProofing: false,
          usStatesTerritories: [],
        }}
      >
        <InPersonOutageAlert />
      </InPersonContext.Provider>,
    ).getByText;
  });

  it('renders the title', () => {
    expect(
      getByText('idv.failure.exceptions.in_person_outage_error_message.post_cta.title'),
    ).to.exist();
  });

  it('renders the body', () => {
    expect(
      getByText('idv.failure.exceptions.in_person_outage_error_message.post_cta.body'),
    ).to.exist();
  });
});
