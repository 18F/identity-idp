require 'rails_helper'

RSpec.describe Agreements::Db::IaasByAgency do
  let(:agency) { create(:agency) }
  let(:partner_account1) { create(:partner_account, agency: agency, requesting_agency: 'DEF') }
  let(:partner_account2) { create(:partner_account, agency: agency, requesting_agency: 'ABC') }
  let(:gtc1) { create(:iaa_gtc, partner_account: partner_account1, gtc_number: 'LGAADEF210001') }
  let(:gtc2) { create(:iaa_gtc, partner_account: partner_account2, gtc_number: 'LGABC210001') }
  let(:gtc1order1) { create(:iaa_order, iaa_gtc: gtc1, order_number: 1) }
  let(:gtc1order2) { create(:iaa_order, iaa_gtc: gtc1, order_number: 2) }
  let(:gtc2order1) { create(:iaa_order, iaa_gtc: gtc2, order_number: 1) }
  let(:iaas) do
    [
      # this is unfortunately order-dependent
      Agreements::Iaa.new(gtc: gtc1, order: gtc1order1),
      Agreements::Iaa.new(gtc: gtc1, order: gtc1order2),
      Agreements::Iaa.new(gtc: gtc2, order: gtc2order1),
    ]
  end
  let(:other_agency_order) { create(:iaa_order) }
  let(:other_agency_gtc) { other_agency_order.iaa_gtc }
  let(:other_agency) { other_agency_gtc.partner_account.agency }

  before { clear_agreements_data }

  it 'returns all agreements encapsulated in an Iaa model grouped by agency' do
    expected = {
      agency.abbreviation => iaas,
      other_agency.abbreviation => [
        Agreements::Iaa.new(gtc: other_agency_gtc, order: other_agency_order),
      ],
    }
    expect(described_class.call).to eq(expected)
  end
end
