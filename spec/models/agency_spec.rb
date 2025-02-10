require 'rails_helper'

RSpec.describe Agency do
  describe 'Associations' do
    it { is_expected.to have_many(:agency_identities).dependent(:destroy) }
    it { is_expected.to have_many(:service_providers).inverse_of(:agency) }
    it { is_expected.to have_many(:partner_accounts).class_name('Agreements::PartnerAccount') }
  end
  describe 'validations' do
    let(:agency) { build_stubbed(:agency) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:abbreviation).case_insensitive }
  end
end
