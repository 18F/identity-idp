require 'rails_helper'

RSpec.describe Agreements::IaaStatus, type: :model do
  describe 'validations and associations' do
    subject { build(:iaa_status) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_presence_of(:order) }
    it { is_expected.to validate_uniqueness_of(:order) }
    it { is_expected.to validate_numericality_of(:order).only_integer }

    it { is_expected.to have_many(:iaa_gtcs).dependent(:restrict_with_exception) }
    it { is_expected.to have_many(:iaa_orders).dependent(:restrict_with_exception) }
  end
end
