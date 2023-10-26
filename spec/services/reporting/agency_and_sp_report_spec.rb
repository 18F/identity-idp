require 'csv'
require 'rails_helper'

RSpec.describe Reporting::AgencyAndSpReport do
  let(:report_date) do
    Date.new(2021, 1, 1).in_time_zone('UTC')
  end

  before { travel_to report_date }

  subject(:report) { described_class.new(report_date) }

  describe '#agency_and_sp_report' do

    subject { report.agency_and_sp_report }

    # OK, so there's existing seed data, it turns out!
    context 'when adding an IDV SP' do
      let!(:idv_sp) { create(:service_provider, :idv, :active) }

      let(:expected_report) do
        [
          ['', 'Number of apps (SPs)', 'Number of agencies'],
          ['Auth', 19, 19],
          ['IDV', 1, 1],
        ]
      end

      it 'has the SP as active' do
        expect(idv_sp).to be_active
      end

      it 'looks like what I expect' do
        expect(subject).to match_array(expected_report)
      end
    end

    # This is a case of a test that really doesn't need to exist anymore, but
    # I wrote it while troubleshooting and kinda feel like leaving it.
    # Actually, this whole thing is a huge mess, lol.
    context 'when there is no IDV data' do
      let(:expected_report) do
        [
          ['', 'Number of apps (SPs)', 'Number of agencies'],
          ['Auth', 19, 19],
          ['IDV', 0, 0],
        ]
      end

      before do
        allow(report).to receive(:idv_sps).and_return([])
      end

      it 'shows 0 for counts without errors' do
        #expect(Agency.count).to eq 0
        expect(subject).to match_array(expected_report)
      end
    end
  end
end
