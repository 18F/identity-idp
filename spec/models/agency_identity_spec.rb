require 'rails_helper'

describe AgencyIdentity do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:agency) }

  describe 'validations' do
    let(:agency_identity) { build_stubbed(:agency_identity) }

    it { is_expected.to validate_presence_of(:uuid) }
  end

  describe '#agency_enabled?' do
    it 'returns true if the agency is enabled' do
      allow(Figaro.env).to receive(:agencies_with_agency_based_uuids).and_return('1')
      ai = AgencyIdentity.new(agency_id: 1, user_id: 1, uuid: 'UUID1')
      expect(ai.agency_enabled?).to eq(true)
    end

    it 'returns false if the agency is disabled' do
      allow(Figaro.env).to receive(:agencies_with_agency_based_uuids).and_return('')
      ai = AgencyIdentity.new(agency_id: 1, user_id: 1, uuid: 'UUID1')
      expect(ai.agency_enabled?).to eq(false)
    end
  end
end
