require 'rails_helper'

RSpec.describe Agreements::IaaOrder, type: :model do
  describe 'validations and associations' do
    subject { create(:iaa_order) }

    it { is_expected.to validate_presence_of(:order_number) }
    it { is_expected.to validate_uniqueness_of(:order_number).scoped_to(:iaa_gtc_id) }
    it do
      is_expected.to validate_numericality_of(:order_number).
        only_integer.
        is_greater_than_or_equal_to(0)
    end
    it { is_expected.to validate_presence_of(:mod_number) }
    it do
      is_expected.to validate_numericality_of(:mod_number).
        only_integer.
        is_greater_than_or_equal_to(0)
    end
    it { is_expected.to validate_presence_of(:pricing_model) }
    it do
      is_expected.to validate_numericality_of(:pricing_model).
        only_integer.
        is_greater_than_or_equal_to(0)
    end
    it do
      is_expected.to validate_numericality_of(:estimated_amount).
        is_less_than(10_000_000_000).
        is_greater_than_or_equal_to(0).
        allow_nil
    end

    it { is_expected.to belong_to(:iaa_gtc) }
    it { is_expected.to belong_to(:iaa_status) }

    it { is_expected.to have_one(:partner_account).through(:iaa_gtc) }
    it { is_expected.to have_many(:integration_usages).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:integrations).through(:integration_usages) }
  end
end
