require 'rails_helper'

RSpec.describe Agreements::PartnerAccountBlueprint do
  let(:status) do
    create(
      :partner_account_status,
      name: 'secret',
      partner_name: 'public',
    )
  end
  let(:account) do
    create(
      :partner_account,
      partner_account_status: status,
      requesting_agency: 'ABC-DEF',
      name: 'Department of Energy Fusion',
      became_partner: '2021-01-01',
    )
  end
  let(:expected) do
    {
      partner_accounts: [
        {
          requesting_agency: 'ABC-DEF',
          name: 'Department of Energy Fusion',
          became_partner: '2021-01-01',
          status: 'public',
        },
      ],
    }.to_json
  end

  it 'renders the appropriate json' do
    expect(described_class.render([account], root: :partner_accounts)).to eq(expected)
  end
end
