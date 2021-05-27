require 'rails_helper'

RSpec.describe Agreements::Reports::AgencyIaasReport do
  let(:agency) { create(:agency, abbreviation: 'ABC') }
  let(:partner_account1) { create(:partner_account, agency: agency, requesting_agency: 'DEF') }
  let(:partner_account2) { create(:partner_account, agency: agency, requesting_agency: 'ABC') }
  let(:gtc1) { create(:iaa_gtc, partner_account: partner_account1, gtc_number: 'LGAADEF210001') }
  let(:gtc2) { create(:iaa_gtc, partner_account: partner_account2, gtc_number: 'LGABC210001') }
  let(:gtc1order1) { create(:iaa_order, iaa_gtc: gtc1, order_number: 1) }
  let(:gtc1order2) { create(:iaa_order, iaa_gtc: gtc1, order_number: 2) }
  let(:gtc2order1) { create(:iaa_order, iaa_gtc: gtc2, order_number: 1) }
  let(:iaas) do
    [
      Agreements::Iaa.new(gtc: gtc1, order: gtc1order1),
      Agreements::Iaa.new(gtc: gtc2, order: gtc2order1),
      Agreements::Iaa.new(gtc: gtc1, order: gtc1order2),
    ]
  end

  it 'uploads the JSON serialization of the passed partner accounts' do
    sorted_iaas = iaas.sort_by { |iaa| [iaa.partner_account, iaa.iaa_number] }
    expected = Agreements::IaaBlueprint.render(sorted_iaas, root: :agreements)
    report_object = described_class.new(agency: agency.abbreviation, iaas: iaas)
    expect(report_object.run).to eq(expected)
  end

  describe '#report_path' do
    it 'nests the report under the downcased agency abbreviation' do
      report_object = described_class.new(agency: agency.abbreviation, iaas: iaas)
      expect(report_object.report_path).to eq('agencies/abc/')
    end
  end
end
