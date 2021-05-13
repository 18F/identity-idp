require 'rails_helper'

RSpec.describe Agreements::IaaBlueprint do
  let(:account) { create(:partner_account, requesting_agency: 'ABC-DEF') }
  let(:status) { create(:iaa_status, name: 'private name', partner_name: 'active') }
  let(:gtc) do
    create(
      :iaa_gtc,
      partner_account: account,
      gtc_number: 'LGABC210001',
      mod_number: 0,
      start_date: '2021-01-01',
      end_date: '2025-12-31',
      estimated_amount: 100_000,
      iaa_status: status,
    )
  end
  let(:order) do
    create(
      :iaa_order,
      iaa_gtc: gtc,
      order_number: 1,
      mod_number: 0,
      start_date: '2021-01-01',
      end_date: '2021-12-31',
      estimated_amount: 20_000.53,
      iaa_status: status,
    )
  end
  let(:iaa) do
    Agreements::Iaa.new(
      gtc: gtc,
      order: order,
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
          gtc_start_date: '2021-01-01',
          gtc_end_date: '2025-12-31',
          gtc_estimated_amount: '100000.0',
          gtc_status: 'active',
          order_number: 1,
          order_mod_number: 0,
          order_start_date: '2021-01-01',
          order_end_date: '2021-12-31',
          order_estimated_amount: '20000.53',
          order_status: 'active',
        },
      ],
    }.to_json
  end

  it 'renders the appropriate json' do
    expect(described_class.render([iaa], root: :agreements)).to eq(expected)
  end
end
