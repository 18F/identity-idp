require 'rails_helper'

RSpec.describe Agreements::IaaAuthsQuery do
  let(:order) { create(:iaa_order, :with_dates) }
  let(:order_issuer) { create(:integration_usage, iaa_order: order).integration.issuer }

  describe '.call' do
    it 'defaults to zero' do
      expect(described_class.call(order: order)).to be_zero
    end

    it 'returns the number of authentications within the order POP' do
      # should ignore every auth but the last
      other_sp = create(:service_provider)
      create_sp_log(issuer: other_sp.issuer, returned_at_offset: 1.day, order: order) # not in order
      create_sp_log(issuer: order_issuer, returned_at_offset: -1.week, order: order) # past
      3.times { create_sp_log(issuer: order_issuer, returned_at_offset: 1.week, order: order) }

      expect(described_class.call(order: order)).to eq(3)
    end

    def create_sp_log(issuer:, returned_at_offset:, order:)
      SpReturnLog.create!(
        requested_at: order.start_date + returned_at_offset - 1.minute,
        request_id: SecureRandom.uuid,
        ial: [1, 2].sample,
        issuer: issuer,
        returned_at: order.start_date + returned_at_offset,
      )
    end
  end
end
