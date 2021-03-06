require 'rails_helper'

RSpec.describe Agreements::Reports::AgencyPartnerAccountsReport do
  let(:agency) { create(:agency, abbreviation: 'ABC') }
  let(:partner_accounts) do
    build_pair(:partner_account, agency: agency).sort_by(&:requesting_agency)
  end

  it 'uploads the JSON serialization of the passed partner accounts' do
    expected = Agreements::PartnerAccountBlueprint.render(partner_accounts, root: :partner_accounts)
    report_object = described_class.new(
      agency: agency.abbreviation,
      partner_accounts: partner_accounts,
    )
    expect(report_object.run).to eq(expected)
  end

  describe '#report_path' do
    it 'nests the report under the downcased agency abbreviation' do
      report_object = described_class.new(
        agency: agency.abbreviation,
        partner_accounts: partner_accounts,
      )
      expect(report_object.report_path).to eq('agencies/abc/')
    end
  end
end
