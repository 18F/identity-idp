require 'rails_helper'

describe PivCac::ExtractCnFromSubject do
  let(:subject) { described_class }

  describe '#call' do
    let(:dn1) { 'C=US, O=U.S. Government, OU=DoD, OU=PKI, OU=CONTRACTOR, CN=DOE.JANE.Q.123456' }
    let(:dn2) { 'CN=DOE.JANE.Q.123456, C=US, O=U.S. Government, OU=DoD, OU=PKI, OU=CONTRACTOR' }
    let(:cn) { 'DOE.JANE.Q.123456' }

    it 'returns the cn field when the cn is on the right' do
      results = subject.call(dn1)

      expect(results).to eq(cn)
    end

    it 'returns the cn field when the cn is on the left' do
      results = subject.call(dn2)

      expect(results).to eq(cn)
    end

    it 'returns nil if the subject is blank' do
      results = subject.call('')

      expect(results).to be_nil
    end
  end
end
