require 'rails_helper'

RSpec.describe Agreements::IaaBlueprint do
  let(:account) { create(:partner_account, requesting_agency: 'ABC-DEF') }
  let(:iaa_start) { Time.zone.yesterday }
  let(:gtc_end) { Time.zone.yesterday + 5.years }
  let(:order_end) { Time.zone.yesterday + 1.year }
  let(:gtc) do
    create(
      :iaa_gtc,
      partner_account: account,
      gtc_number: 'LGABC210001',
      mod_number: 0,
      start_date: iaa_start,
      end_date: gtc_end,
      estimated_amount: 100_000,
    )
  end
  let(:order) do
    create(
      :iaa_order,
      iaa_gtc: gtc,
      order_number: 1,
      mod_number: 0,
      start_date: iaa_start,
      end_date: order_end,
      estimated_amount: 20_000.53,
    )
  end
  let(:iaa) do
    Agreements::Iaa.new(
      gtc: gtc,
      order: order,
      ial2_users: 10,
      authentications: {
        'issuer1' => 100,
        'issuer2' => 1_000,
      },
    )
  end
  let(:expected) do
    {
      agreements: [
        {
          iaa_number: 'LGABC210001-0001-0000',
          partner_account: 'ABC-DEF',
          gtc_number: 'LGABC210001',
          gtc_mod_number: 0,
          gtc_start_date: iaa_start.strftime('%Y-%m-%d'),
          gtc_end_date: gtc_end.strftime('%Y-%m-%d'),
          gtc_estimated_amount: '100000.0',
          gtc_status: 'active',
          order_number: 1,
          order_mod_number: 0,
          order_start_date: iaa_start.strftime('%Y-%m-%d'),
          order_end_date: order_end.strftime('%Y-%m-%d'),
          order_estimated_amount: '20000.53',
          order_status: 'active',
          ial2_users: 10,
          authentications: {
            'issuer1' => 100,
            'issuer2' => 1_000,
          },
        },
      ],
    }.to_json
  end

  it 'renders the appropriate json' do
    expect(described_class.render([iaa], root: :agreements)).to eq(expected)
  end
end
