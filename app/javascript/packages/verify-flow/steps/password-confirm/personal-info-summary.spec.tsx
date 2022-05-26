import { render } from '@testing-library/react';
import PersonalInfoSummary from './personal-info-summary';
import type { VerifyFlowValues } from '../../verify-flow';

describe('PersonalInfoSummary', () => {
  const DEFAULT_PII: VerifyFlowValues = {
    firstName: 'FAKEY',
    lastName: 'MCFAKERSON',
    address1: '1 FAKE RD',
    city: 'GREAT FALLS',
    state: 'MT',
    zipcode: '59010',
    dob: '1938-10-06',
  };

  it('renders dates accurately', () => {
    const { getByText } = render(<PersonalInfoSummary pii={DEFAULT_PII} />);

    expect(getByText('October 6, 1938')).to.exist();
  });

  it('renders address', () => {
    const { getByText, rerender } = render(<PersonalInfoSummary pii={DEFAULT_PII} />);

    let address = getByText('1 FAKE RDGREAT FALLS, MT 59010');

    expect([...address.childNodes].filter((node) => node.nodeName === 'BR')).to.have.lengthOf(1);

    rerender(<PersonalInfoSummary pii={{ ...DEFAULT_PII, address2: 'PO BOX 1' }} />);

    address = getByText('1 FAKE RDPO BOX 1GREAT FALLS, MT 59010');

    expect([...address.childNodes].filter((node) => node.nodeName === 'BR')).to.have.lengthOf(2);
  });
});
