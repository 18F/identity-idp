require 'rails_helper'

describe AgencyIdentity do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:agency) }

  describe 'validations' do
    let(:agency_identity) { build_stubbed(:agency_identity) }

    it { is_expected.to validate_presence_of(:uuid) }
  end
end
