require 'rails_helper'

describe PivCac::CnFieldsFromSubject do
  describe '#call' do
    let(:subject) { 'C=US, O=U.S. Government, OU=DoD, OU=PKI, OU=CONTRACTOR, CN=DOE.JANE.Q.123456' }
    let(:fields) { %w[DOE JANE Q 123456] }

    it 'returns the fields' do
      results = PivCac::CnFieldsFromSubject.call(subject)
      expect(fields).to eq(results)
    end

    it 'returns an empty array if the subject is blank' do
      results = PivCac::CnFieldsFromSubject.call('')
      expect([]).to eq(results)
    end
  end
end
