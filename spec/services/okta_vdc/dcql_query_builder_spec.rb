require 'rails_helper'

RSpec.describe OktaVdc::DcqlQueryBuilder do
  describe '.build' do
    subject(:query) { described_class.build }

    it 'returns a valid DCQL query structure' do
      expect(query[:credentials]).to be_an(Array)
      expect(query[:credentials].length).to eq(1)
    end

    it 'requests mDL document type' do
      credential = query[:credentials].first
      expect(credential[:format]).to eq('mso_mdoc')
      expect(credential[:meta][:doctype_value]).to eq('org.iso.18013.5.1.mDL')
    end

    it 'requests identity claims' do
      claims = query[:credentials].first[:claims]
      claim_names = claims.map { |c| c[:path].last }

      expect(claim_names).to include('given_name', 'family_name', 'birth_date')
      expect(claim_names).to include('resident_address', 'resident_city', 'resident_state')
    end

    it 'sets intent_to_retain to false for all claims' do
      claims = query[:credentials].first[:claims]
      expect(claims).to all(include(intent_to_retain: false))
    end
  end
end
