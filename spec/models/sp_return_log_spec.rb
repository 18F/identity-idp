require 'rails_helper'

RSpec.describe SpReturnLog, type: :model do
  describe 'associations' do
    subject { described_class.new }

    it { is_expected.to belong_to(:user) }
    it do
      is_expected.to belong_to(:service_provider).
        inverse_of(:sp_return_logs).
        with_foreign_key(:issuer).
        with_primary_key(:issuer)
    end
  end
end
