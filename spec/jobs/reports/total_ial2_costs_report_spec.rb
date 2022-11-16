require 'rails_helper'

RSpec.describe Reports::TotalIal2CostsReport do
  subject(:report) { described_class.new }

  describe '#perform' do
    let(:issuer1) { 'issuer1' }
    let(:issuer2) { 'issuer2' }

    let!(:sp1) { create(:service_provider, issuer: issuer1, friendly_name: issuer1) }
    let!(:sp2) { create(:service_provider, issuer: issuer2, friendly_name: issuer2) }

    let(:date) { Date.new(2022, 4, 1) }
    let(:yesterday) { Date.new(2022, 3, 31) }
    let(:yesterday_utc) { yesterday.in_time_zone('UTC') }
    let(:too_old) { Date.new(2021, 12, 31) }

    before do
      SpCost.create(
        agency_id: 1,
        issuer: issuer1,
        cost_type: 'authentication',
        created_at: yesterday_utc,
        ial: 2,
      )
      SpCost.create(
        agency_id: 2,
        issuer: issuer2,
        cost_type: 'authentication',
        created_at: yesterday_utc,
        ial: 2,
      )

      SpCost.create(
        agency_id: 1, issuer: issuer1, cost_type: 'sms', created_at: yesterday_utc, ial: 2,
      )

      # rows that get ignored
      SpCost.create(
        agency_id: 2, issuer: issuer2, cost_type: 'user_added', created_at: too_old, ial: 2,
      )
      SpCost.create(
        agency_id: 2, issuer: issuer2, cost_type: 'user_added', created_at: yesterday_utc, ial: 1,
      )
    end

    it 'writes a CSV report to S3' do
      expect(report).to receive(:save_report) do |report_name, body, extension:|
        expect(report_name).to eq(described_class::REPORT_NAME)
        expect(extension).to eq('csv')

        csv = CSV.parse(body, headers: true)
        expect(csv.length).to eq(2)

        row = csv.first
        expect(row['date']).to eq(yesterday.to_s)
        expect(row['cost_type']).to eq('authentication')
        expect(row['ial']).to eq(2.to_s)
        expect(row['count']).to eq(2.to_s)

        row = csv[1]
        expect(row['date']).to eq(yesterday.to_s)
        expect(row['cost_type']).to eq('sms')
        expect(row['ial']).to eq(2.to_s)
        expect(row['count']).to eq(1.to_s)
      end

      report.perform(date)
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
