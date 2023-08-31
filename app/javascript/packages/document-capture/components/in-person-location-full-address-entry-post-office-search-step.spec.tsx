import { render } from '@testing-library/react';
import { SWRConfig } from 'swr';
import { ComponentType } from 'react';
import InPersonLocationFullAddressEntryPostOfficeSearchStep from './in-person-location-full-address-entry-post-office-search-step';

const DEFAULT_PROPS = {
  toPreviousStep() {},
  onChange() {},
  value: {},
  registerField() {},
};

describe('InPersonLocationFullAddressEntryPostOfficeSearchStep', () => {
  const wrapper: ComponentType = ({ children }) => (
    <SWRConfig value={{ provider: () => new Map() }}>{children}</SWRConfig>
  );

  it('renders the step', () => {
    const { getByRole } = render(
      <InPersonLocationFullAddressEntryPostOfficeSearchStep {...DEFAULT_PROPS} />,
      {
        wrapper,
      },
    );

    expect(getByRole('heading', { name: 'in_person_proofing.headings.po_search.location' }));
  });
});
