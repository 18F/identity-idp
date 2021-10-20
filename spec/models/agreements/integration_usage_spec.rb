require 'rails_helper'

RSpec.describe Agreements::IntegrationUsage, type: :model do
  describe 'validations and associations' do
    subject { create(:integration_usage) }

    it { is_expected.to validate_presence_of(:iaa_order) }
    it { is_expected.to validate_presence_of(:integration) }
    it { is_expected.to validate_uniqueness_of(:integration_id).scoped_to(:iaa_order_id) }

    xit 'validates that the IAA Order and Integration belong to the same account' do
      subject.iaa_order = create(:iaa_order)
      expect(subject).not_to be_valid
    end

    it { is_expected.to belong_to(:iaa_order) }
    it { is_expected.to belong_to(:integration) }

    it { is_expected.to have_one(:partner_account).through(:integration) }
  end
end
