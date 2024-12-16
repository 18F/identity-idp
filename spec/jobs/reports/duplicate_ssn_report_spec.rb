require 'rails_helper'
require 'csv'

RSpec.describe Reports::DuplicateSsnReport do
  let(:report_date) { Date.new(2022, 2, 2) }

  subject(:report) { described_class.new.tap { |r| r.report_date = report_date } }

  describe '#perform' do
    it 'runs the report and uploads to S3' do
      expect(report).to receive(:save_report)

      report.perform(report_date)
    end
  end

  describe '#report_body' do
    subject(:report_body) { report.report_body }

    context 'with no data' do
      it 'is an empty report' do
        csv = CSV.parse(report_body, headers: true)

        expect(csv).to be_empty
      end
    end

    context 'with data' do
      let(:ssn_fingerprint1) { 'aaa' }
      let(:ssn_fingerprint2) { 'bbb' }

      let!(:unique_profile) do
        create(
          :profile,
          :active,
          ssn_signature: ssn_fingerprint1,
          activated_at: report_date,
        )
      end

      let!(:fingerprint2_today_profile) do
        create(
          :profile,
          :active,
          ssn_signature: ssn_fingerprint2,
          activated_at: report_date,
        ).tap(&:reload)
      end

      let!(:fingerprint2_previous_profiles) do
        [
          create(
            :profile,
            active: false,
            ssn_signature: ssn_fingerprint2,
            activated_at: report_date - 10.days,
          ),
          create(
            :profile,
            active: false,
            ssn_signature: ssn_fingerprint2,
            activated_at: nil,
          ),
        ].map(&:reload)
      end

      it 'creates csv with corresponding data', aggregate_failures: true do
        csv = CSV.parse(report_body, headers: true)
        expect(csv.length).to eq(3)

        expect(csv.find { |r| r['uuid'] == unique_profile.user.uuid })
          .to be_nil, 'does not include unique users in the report'

        today_user = fingerprint2_today_profile.user
        today_row = csv.find { |r| r['uuid'] == today_user.uuid }

        expect_row_matches_profile(row: today_row, profile: fingerprint2_today_profile)
        expect(today_row['new_account']).to eq('true')

        fingerprint2_previous_profiles.each do |profile|
          row = csv.find { |r| r['uuid'] == profile.user.uuid }

          expect_row_matches_profile(row:, profile:)
          expect(row['new_account']).to eq('false')
        end
      end

      def expect_row_matches_profile(row:, profile:)
        expect(row).to be
        expect(row['uuid']).to eq(profile.user.uuid)
        expect(Time.zone.parse(row['account_created_at']).to_i).to eq(profile.user.created_at.to_i)
        if profile.activated_at
          expect(Time.zone.parse(row['identity_verified_at']).to_i).to eq(profile.activated_at.to_i)
        end
        expect(row['profile_active']).to eq(profile.active.to_s)
        expect(row['ssn_fingerprint']).to eq(ssn_fingerprint2)
        expect(row['count_ssn_fingerprint']).to eq('3')
        expect(row['count_active_ssn_fingerprint']).to eq('1')
      end
    end
  end
end
