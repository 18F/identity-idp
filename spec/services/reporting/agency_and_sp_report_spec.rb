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
    clear_agreements_data
    Agency.destroy_all
    ServiceProvider.destroy_all
  end

  subject(:report) { described_class.new(report_date) }

  let(:agency) do
    create(
      :agency,
      partner_accounts: [
        build(
          :partner_account,
          became_partner: report_date - 10.days,
          partner_account_status: build(
            :partner_account_status, name: 'active'
          ),
        ),
      ],
    )
  end

  describe '#agency_and_sp_report' do
    subject { report.agency_and_sp_report }

    context 'when adding a non-IDV SP' do
      let!(:auth_sp) do
        create(
          :service_provider,
          :external,
          :active,
          agency:,
          identities: [build(:service_provider_identity)],
        )
      end
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
      let!(:inactive_sp) { create(:service_provider, :external, agency:, identities: []) }
      let(:expected_report) do
        [
          header_row,
          ['Auth', 0, 1],
          ['IDV', 0, 0],
          ['Total', 0, 1],
        ]
      end

      it 'includes the agency but not the inactive SP' do
        expect(subject).to match_array(expected_report)
      end
    end

    context 'when adding an IDV SP to a non-IDV Agency' do
      let!(:initial_sp) do
        create(
          :service_provider,
          :external,
          :active,
          agency:,
          identities: [build(:service_provider_identity)],
        )
      end

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

        create(
          :service_provider,
          :external,
          :active,
          :idv,
          agency:,
          identities: [build(:service_provider_identity)],
        )

        # The report gets memoized, so we need to reconstruct it here:
        new_report = described_class.new(report_date)
        expect(new_report.agency_and_sp_report).to match_array(updated_report)
      end
    end

    context 'when adding an IDV SP' do
      let!(:idv_sp) do
        create(
          :service_provider,
          :external,
          :idv,
          :active,
          agency:,
          identities: [build(:service_provider_identity)],
        )
      end

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
