require 'rails_helper'
require 'reporting/proofing_rate_report'

RSpec.describe Reporting::ProofingRateReport do
  let(:start_date) { Time.new(2022, 1, 1) }

  subject(:report) do
    Reporting::ProofingRateReport.new
  end

  before do
    # This is borderline copypasta
    cloudwatch_client = double(
      'Reporting::CloudwatchClient',
      fetch: [
               # Online verification user
               { 'user_id' => 'user1', 'name' => 'IdV: doc auth welcome visited' },
             ]
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
  end

  # FIXME: Why is this still trying to call Cloudwatch?!
  describe '#report_for' do
    it 'shows a number' do
      expect(report.report_for(start_date: start_date)).to eq([])
    end
  end

end
