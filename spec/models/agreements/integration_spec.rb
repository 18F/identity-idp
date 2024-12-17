require 'rails_helper'

RSpec.describe Agreements::Integration, type: :model do
  describe 'validations and associations' do
    subject { create(:integration) }

    it { is_expected.to validate_presence_of(:issuer) }
    it { is_expected.to validate_uniqueness_of(:issuer) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:dashboard_identifier).allow_nil }
    it do
      is_expected.to validate_numericality_of(:dashboard_identifier)
        .only_integer
        .is_greater_than(0)
    end

    it { is_expected.to belong_to(:partner_account) }
    it { is_expected.to belong_to(:integration_status) }
    it { is_expected.to belong_to(:service_provider) }

    it { is_expected.to have_many(:integration_usages).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:iaa_orders).through(:integration_usages) }
  end
end
