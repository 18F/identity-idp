require 'csv'
require 'rails_helper'

RSpec.describe Reporting::AgencyAndSpReport do
  let(:report_date) do
    Date.new(2021, 1, 1).in_time_zone('UTC')
  end

  let(:header_row) do
    ['', 'Number of apps (SPs)', 'Number of agencies and states']
  end

  before { travel_to report_date }

  # Wipe the pre-seeded data. It's easier to start from a clean slate.
  before do
    Agreements::IntegrationUsage.destroy_all
    Agreements::IaaOrder.destroy_all
    Agreements::Integration.destroy_all
    Agreements::IntegrationStatus.destroy_all
    Agreements::IaaGtc.destroy_all
    Agreements::PartnerAccount.destroy_all
    Agreements::PartnerAccountStatus.destroy_all
    Agency.destroy_all
    ServiceProvider.destroy_all
  end

  subject(:report) { described_class.new(report_date) }

  describe '#agency_and_sp_report' do
    subject { report.agency_and_sp_report }

    context 'when adding a non-IDV SP' do
      let!(:auth_sp) { create(:service_provider, :active) }
      let(:expected_report) do
        [
          header_row,
          ['Auth', 1, 1],
          ['IDV', 0, 0],
          ['Total', 1, 1],
        ]
      end

      it 'counts the SP and its Agency as auth (non-IDV)' do
        expect(subject).to match_array(expected_report)
      end
    end

    context 'when adding an inactive SP' do
      let!(:inactive_sp) { create(:service_provider) }
      let(:expected_report) do
        [
          header_row,
          ['Auth', 0, 1],
          ['IDV', 0, 0],
          ['Total', 0, 1],
        ]
      end

      # Agencies don't have a sense of 'active' and are included.
      it 'includes the agency but not the inactive SP' do
        expect(subject).to match_array(expected_report)
      end
    end

    context 'when adding an IDV SP to a non-IDV Agency' do
      let!(:initial_sp) { create(:service_provider, :active) }
      let!(:agency) { initial_sp.agency }

      let(:initial_report) do
        [
          header_row,
          ['Auth', 1, 1],
          ['IDV', 0, 0],
          ['Total', 1, 1],
        ]
      end

      let(:updated_report) do
        [
          header_row,
          ['Auth', 1, 0],
          ['IDV', 1, 1],
          ['Total', 2, 1],
        ]
      end

      it 'becomes an IDV agency' do
        expect(subject).to match_array(initial_report)

        create(:service_provider, :active, :idv, agency: agency)

        # The report gets memoized, so we need to reconstruct it here:
        new_report = described_class.new(report_date)
        expect(new_report.agency_and_sp_report).to match_array(updated_report)
      end
    end

    context 'when adding an IDV SP' do
      let!(:idv_sp) { create(:service_provider, :idv, :active) }

      let(:expected_report) do
        [
          header_row,
          ['Auth', 0, 0],
          ['IDV', 1, 1],
          ['Total', 1, 1],
        ]
      end

      it 'counts the SP and its Agency as IDV' do
        expect(subject).to match_array(expected_report)
      end
    end
  end
end
