require 'rails_helper'

describe Agency do
  describe 'Associations' do
    it { is_expected.to have_many(:agency_identities) }
  end
  describe 'validations' do
    let(:agency) { build_stubbed(:agency) }

    it { is_expected.to validate_presence_of(:name) }
  end
end
