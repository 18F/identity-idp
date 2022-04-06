require 'rails_helper'

RSpec.describe Reports::SpCostReportV2 do
  subject(:report) { described_class.new }

  describe '#perform' do
    let(:issuer1) { 'issuer1' }
    let(:app_id1) { 'app_id1' }
    let(:issuer2) { 'issuer2' }
    let(:app_id2) { 'app_id2' }

    let!(:sp1) do
      create(:service_provider, issuer: issuer1, friendly_name: issuer1, app_id: app_id1)
    end
    let!(:sp2) do
      create(:service_provider, issuer: issuer2, friendly_name: issuer2, app_id: app_id2)
    end

    let(:date) { Time.zone.today }
    let(:yesterday) { Date.yesterday }
    let(:too_old) { today - (Reports::SpCostReportV2::NUM_LOOKBACK_DAYS + 1).days }

    before do
      SpCost.create(issuer: issuer1, cost_type: 'authentication', created_at: yesterday, ial: 1)
      SpCost.create(issuer: issuer1, cost_type: 'authentication', created_at: yesterday, ial: 1)

      SpCost.create(issuer: issuer2, cost_type: 'sms', created_at: yesterday, ial: 2)

      SpCost.create(issuer: issuer2, cost_type: 'user_added', created_at: too_old)
    end

    it 'writes a CSV report to S3' do
      expect(report).to receive(:save_report).with do |report_name, body, extension:|
        expect(report_name).to eq(described_class::REPORT_NAME)
        expect(extension).to eq('csv')

        csv = CSV.parse(body, headers: true)
        expect(csv.length).to eq(2)

        row = csv.first
        expect(row['date']).to eq(yesterday.to_s)
        expect(row['issuer']).to eq(issuer1)
        expect(row['ial']).to eq(1)
        expect(row['cost_type']).to eq('authentication')
        expect(row['app_id']).to eq(app_id1)
        expect(row['count']).to eq(2)

        row = csv.last
        expect(row['date']).to eq(yesterday.to_s)
        expect(row['issuer']).to eq(issuer2)
        expect(row['ial']).to eq(2)
        expect(row['cost_type']).to eq('sms')
        expect(row['app_id']).to eq(app_id2)
        expect(row['count']).to eq(1)
      end
    end
  end

  describe '#good_job_concurrency_key' do
    let(:date) { Time.zone.today }

    it 'is the job name and the date' do
      job = described_class.new(date)
      expect(job.good_job_concurrency_key).
        to eq("#{described_class::REPORT_NAME}-#{date}")
    end
  end
end
