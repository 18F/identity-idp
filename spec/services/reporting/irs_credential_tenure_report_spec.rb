require 'rails_helper'

RSpec.describe Reporting::IrsCredentialTenureReport do
  let(:report_date) { Date.new(2025, 5, 31) }
  let(:issuers) { ['urn:gov:gsa:openidconnect.profiles:sp:sso:irs:sample'] }
  subject(:report) { described_class.new(report_date, issuers: issuers) }

  before do
    travel_to report_date
  end

  describe '#total_user_count' do
    it 'returns 0 when no IRS identities exist' do
      create_list(:user, 3)
      expect(report.send(:total_user_count)).to eq(0)
    end
  end

  describe '#average_credential_tenure_months' do
    it 'returns 0 when no IRS identities exist' do
      create(:user, created_at: report_date - 2.months)
      create(:user, created_at: report_date - 4.months)
      expect(report.send(:average_credential_tenure_months)).to eq(0)
    end
  end

  describe '#irs_credential_tenure_report' do
    it 'returns a table with headers and values' do
      table = report.irs_credential_tenure_report
      expect(table.first).to eq(['Metric', 'Value'])
      expect(table.last.first).to eq('Credential Tenure')
    end
  end

  describe '#irs_credential_tenure_report_definition' do
    it 'returns a table with metric definitions' do
      table = report.irs_credential_tenure_report_definition
      expect(table.first).to eq(['Metric', 'Definition'])
      expect(table.last.first).to eq('Credential Tenure')
    end
  end

  describe '#irs_credential_tenure_report_overview' do
    it 'returns a table with overview information' do
      table = report.irs_credential_tenure_report_overview
      expect(table.first.first).to eq('Report Timeframe')
      expect(table[1].first).to eq('Report Generated')
      expect(table[2].first).to eq('Issuer')
    end
  end

  describe '#credential_tenure_emailable_report' do
    it 'returns an EmailableReport with correct attributes' do
      emailable = report.credential_tenure_emailable_report
      expect(emailable.title).to eq('IRS Credential Tenure Metric')
      expect(emailable.table.first).to eq(['Metric', 'Value'])
      expect(emailable.filename).to eq('Credential_Tenure_Metric')
    end
  end

  describe '#irs_credential_tenure_definition' do
    it 'returns an EmailableReport for definitions' do
      emailable = report.irs_credential_tenure_definition
      expect(emailable.title).to eq('Definitions')
      expect(emailable.table.first).to eq(['Metric', 'Definition'])
      expect(emailable.filename).to eq('Definitions')
    end
  end

  describe '#irs_credential_tenure_overview' do
    it 'returns an EmailableReport for overview' do
      emailable = report.irs_credential_tenure_overview
      expect(emailable.title).to eq('Overview')
      expect(emailable.table.first.first).to eq('Report Timeframe')
      expect(emailable.filename).to eq('Overview')
    end
  end
end
