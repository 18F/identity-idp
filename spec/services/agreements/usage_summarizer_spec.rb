require 'rails_helper'

describe Agreements::UsageSummarizer do
  let(:gtc) { create(:iaa_gtc, gtc_number: 'LGABC123') }
  let(:order1) do
    create(
      :iaa_order,
      iaa_gtc: gtc,
      order_number: 1,
      start_date: Time.zone.today,
      end_date: Time.zone.today + 1.week,
    )
  end
  let(:order2) do
    create(
      :iaa_order,
      iaa_gtc: gtc,
      order_number: 2,
      start_date: Time.zone.today + 8.days,
      end_date: Time.zone.today + 8.days + 1.week,
    )
  end
  let(:integration1) { create(:integration, partner_account: gtc.partner_account) }
  let(:integration2) { create(:integration, partner_account: gtc.partner_account) }
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:iaas) do
    [
      Agreements::Iaa.new(gtc: gtc, order: order1),
      Agreements::Iaa.new(gtc: gtc, order: order2),
    ]
  end

  before do
    order1.integrations << integration1
    order1.integrations << integration2
    order2.integrations << integration1
    order2.integrations << integration2

    # order1
    create_sp_log(sp: integration1, user: user1, ial: 1, time: Time.zone.today + 1.day)
    create_sp_log(sp: integration1, user: user1, ial: 1, time: Time.zone.today + 2.days)
    create_sp_log(sp: integration1, user: user2, ial: 1, time: Time.zone.today + 2.days)
    create_sp_log(sp: integration2, user: user1, ial: 2, time: Time.zone.today + 1.day)
    create_sp_log(sp: integration2, user: user1, ial: 2, time: Time.zone.today + 2.days)

    # order2
    create_sp_log(sp: integration2, user: user2, ial: 2, time: Time.zone.today + 9.days)
    create_sp_log(sp: integration2, user: user1, ial: 2, time: Time.zone.today + 10.days)
  end

  describe '.call' do
    it 'returns the appropriate usage summary' do
      output = described_class.call(iaas: iaas)

      expect(output[:iaas]['LGABC123-0001-0000'].authentications).to \
        eq({ integration1.issuer => 3, integration2.issuer => 2 })
      expect(output[:iaas]['LGABC123-0001-0000'].ial2_users).to \
        eq(Set.new([user1.id]))
      expect(output[:iaas]['LGABC123-0002-0000'].authentications).to \
        eq({ integration2.issuer => 2 })
      expect(output[:iaas]['LGABC123-0002-0000'].ial2_users).to \
        eq(Set.new([user1.id, user2.id]))
    end
  end

  def create_sp_log(sp:, user:, ial:, time:)
    SpReturnLog.create!(
      issuer: sp.issuer,
      user_id: user.id,
      ial: ial,
      returned_at: time,
      requested_at: time - 1.minute,
      request_id: SecureRandom.uuid,
    )
  end
end
