require 'rails_helper'

RSpec.describe Agreements::IaaIal2UsersQuery do
  let(:order) { create(:iaa_order, :with_dates) }
  let(:order_issuer) { create(:integration_usage, iaa_order: order).integration.issuer }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:user3) { create(:user) }
  let(:non_ial2_user) { create(:user) }

  describe '.call' do
    it 'defaults to zero' do
      expect(described_class.call(order: order)).to be_zero
    end

    it 'returns the number of IAL2 users within the order POP' do
      # not in order
      other_sp = create(:service_provider)
      create_sp_log(
        issuer: other_sp.issuer,
        returned_at_offset: 1.day,
        order: order,
        ial: 2,
        user: user1,
      )
      # in the past
      create_sp_log(
        issuer: order_issuer,
        returned_at_offset: -1.day,
        order: order,
        ial: 2,
        user: user2,
      )
      # not IAL2
      create_sp_log(
        issuer: order_issuer,
        returned_at_offset: 1.day,
        order: order,
        ial: 1,
        user: non_ial2_user,
      )
      # this one counts!
      create_sp_log(
        issuer: order_issuer,
        returned_at_offset: 1.day,
        order: order,
        ial: 2,
        user: user3,
      )

      expect(described_class.call(order: order)).to eq(1)
    end

    def create_sp_log(issuer:, returned_at_offset:, order:, ial:, user:)
      SpReturnLog.create!(
        requested_at: order.start_date + returned_at_offset - 1.minute,
        request_id: SecureRandom.uuid,
        ial: ial,
        issuer: issuer,
        returned_at: order.start_date + returned_at_offset,
        user_id: user.id,
      )
    end
  end
end
