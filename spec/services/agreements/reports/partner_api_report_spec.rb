require 'rails_helper'

RSpec.describe Agreements::Reports::PartnerApiReport do
  let(:today) { Time.zone.today }

  describe '#perform' do
    before do
      allow(IdentityConfig.store).to receive(:enable_partner_api).and_return(true)
      allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(false)
    end

    it 'runs a series of reports' do
      # just a smoke test
      expect(described_class.new.perform(today)).to eq(true)
    end
  end

  describe '#good_job_concurrency_key' do
    it 'is the job name and the date' do
      job = described_class.new(today)
      expect(job.good_job_concurrency_key).to eq("partner-api-report-#{today}")
    end
  end
end
