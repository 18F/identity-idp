require 'rails_helper'

RSpec.describe Agreements::PartnerAccount, type: :model do
  describe 'validations and associations' do
    subject { create(:partner_account) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:requesting_agency) }
    it { is_expected.to validate_uniqueness_of(:requesting_agency) }

    it { is_expected.to belong_to(:agency) }
    it { is_expected.to belong_to(:partner_account_status) }

    it { is_expected.to have_many(:iaa_gtcs) }
    it { is_expected.to have_many(:iaa_orders).through(:iaa_gtcs) }
    it { is_expected.to have_many(:integrations) }
  end
end
