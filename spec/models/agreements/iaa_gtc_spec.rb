require 'rails_helper'

RSpec.describe Agreements::IaaGtc, type: :model do
  describe 'validations and associations' do
    subject { create(:iaa_gtc) }

    it { is_expected.to validate_presence_of(:gtc_number) }
    it { is_expected.to validate_uniqueness_of(:gtc_number) }
    it { is_expected.to validate_presence_of(:mod_number) }
    it do
      is_expected.to validate_numericality_of(:mod_number).
        only_integer.
        is_greater_than_or_equal_to(0)
    end
    it do
      is_expected.to validate_numericality_of(:estimated_amount).
        is_less_than(10_000_000_000).
        is_greater_than_or_equal_to(0).
        allow_nil
    end

    it { is_expected.to belong_to(:partner_account) }
    it { is_expected.to belong_to(:iaa_status) }

    it { is_expected.to have_many(:iaa_orders).dependent(:restrict_with_exception) }
  end
end
