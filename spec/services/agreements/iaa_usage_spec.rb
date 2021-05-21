require 'rails_helper'

describe Agreements::IaaUsage do
  let(:partner_account) { create(:partner_account) }
  let(:integration) { create(:integration, partner_account: partner_account) }
  let(:order) do
    create(
      :iaa_order,
      iaa_gtc: create(:iaa_gtc, partner_account: partner_account),
      start_date: Time.zone.today,
      end_date: Time.zone.today + 7.days,
    )
  end
  let(:usage_obj) { described_class.new(order: order) }
  let(:user) { create(:user) }
  let(:other_sp) { create(:service_provider) }

  before { order.integrations << integration }

  describe 'defaults' do
    it 'returns an empty hash defaulting to zero for authentications' do
      expect(usage_obj.authentications).to eq({})
      expect(usage_obj.authentications['foo']).to eq(0)
    end

    it 'returns an empty set for ial2_users' do
      expect(usage_obj.ial2_users).to eq(Set.new)
    end
  end

  describe '#count' do
    it 'correctly counts IAL1 authentications within the PoP' do
      log =
        create_return_log(sp: integration, user: user, ial: 1, returned: Time.zone.today + 1.day)
      usage_obj.count(log)

      expect(usage_obj.authentications).to eq({ integration.issuer => 1 })
      expect(usage_obj.ial2_users).to eq(Set.new)
    end

    it 'correctly counts IAL2 authentications within the PoP' do
      log =
        create_return_log(sp: integration, user: user, ial: 2, returned: Time.zone.today + 1.day)
      usage_obj.count(log)

      expect(usage_obj.authentications).to eq({ integration.issuer => 1 })
      expect(usage_obj.ial2_users).to eq(Set.new([user.id]))
    end

    it 'correctly skips return logs outside the PoP' do
      log =
        create_return_log(sp: integration, user: user, ial: 2, returned: Time.zone.today - 1.day)

      expect { usage_obj.count(log) }.not_to change { usage_obj.authentications }
      expect { usage_obj.count(log) }.not_to change { usage_obj.ial2_users }
    end

    it 'correctly skipes return logs for other SPs' do
      log =
        create_return_log(sp: other_sp, user: user, ial: 2, returned: Time.zone.today + 1.day)

      expect { usage_obj.count(log) }.not_to change { usage_obj.authentications }
      expect { usage_obj.count(log) }.not_to change { usage_obj.ial2_users }
    end

    it 'returns a copy of itself with the updated usage metrics' do
      log =
        create_return_log(sp: integration, user: user, ial: 2, returned: Time.zone.today + 1.day)

      expect(usage_obj.count(log)).to be_an_instance_of(described_class)
    end
  end

  def create_return_log(sp:, user:, ial:, returned:)
    create(
      :sp_return_log,
      issuer: sp.issuer,
      user_id: user.id,
      ial: ial,
      requested_at: returned - 1.minute,
      returned_at: returned,
    )
  end
end
