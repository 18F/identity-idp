require 'rails_helper'
require 'csv'

RSpec.describe Reporting::TotalUserCountReport do
  let(:report_date) do
    Date.new(2021, 3, 1).in_time_zone('UTC')
  end

  let(:expected_report) do
    [
      [
        'Metric',
        'All Users',
        'Verified users (Legacy IDV)',
        'Verified users (Facial Matching)',
        'Time Range Start',
        'Time Range End',
      ],
      [
        'All-time count',
        expected_total_count,
        expected_verified_legacy_idv_count,
        expected_verified_facial_match_count,
        '-',
        Date.new(2021, 3, 1),
      ],
      [
        'All-time fully registered',
        expected_total_fully_registered,
        '-',
        '-',
        '-',
        Date.new(2021, 3, 1),
      ],
      [
        'New users count',
        expected_new_count,
        expected_new_verified_legacy_idv_count,
        expected_new_verified_facial_match_count,
        Date.new(2021, 3, 1),
        Date.new(2021, 3, 31),
      ],
      [
        'Annual users count',
        expected_annual_count,
        expected_annual_verified_legacy_idv_count,
        expected_annual_verified_facial_match_count,
        Date.new(2020, 10, 1),
        Date.new(2021, 9, 30),
      ],
    ]
  end

  subject(:report) { described_class.new(report_date) }

  before { travel_to report_date }

  describe '#total_user_count_report' do
    shared_examples 'a report with the specified counts' do
      it 'returns a report with the expected counts', aggregate_failures: true do
        report.total_user_count_report.zip(expected_report).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end

    context 'with only a non-verified user' do
      before { create(:user) }
      let(:expected_total_count) { 1 }
      let(:expected_verified_legacy_idv_count) { 0 }
      let(:expected_verified_facial_match_count) { 0 }
      let(:expected_total_fully_registered) { 0 }
      let(:expected_new_count) { 1 }
      let(:expected_new_verified_legacy_idv_count) { 0 }
      let(:expected_new_verified_facial_match_count) { 0 }
      let(:expected_annual_count) { expected_total_count }
      let(:expected_annual_verified_legacy_idv_count) { 0 }
      let(:expected_annual_verified_facial_match_count) { 0 }

      it_behaves_like 'a report with the specified counts'
    end

    context 'with 2 users, 1 from more than a year ago' do
      let!(:recent_user) { create(:user) }
      let!(:old_user) { create(:user, created_at: report_date - 13.months) }

      let(:expected_total_count) { 2 }
      let(:expected_verified_legacy_idv_count) { 0 }
      let(:expected_verified_facial_match_count) { 0 }
      let(:expected_total_fully_registered) { 0 }
      let(:expected_new_count) { 1 }
      let(:expected_new_verified_legacy_idv_count) { 0 }
      let(:expected_new_verified_facial_match_count) { 0 }
      let(:expected_annual_count) { 1 }
      let(:expected_annual_verified_legacy_idv_count) { 0 }
      let(:expected_annual_verified_facial_match_count) { 0 }

      it_behaves_like 'a report with the specified counts'
    end

    context 'with one legacy verified and one non-verified user' do
      before do
        user1 = create(:user)
        user2 = create(:user)
        create(:profile, :active, :verified, user: user1)
        # MW: The :verified trait doesn't set active: true. This feels confusing.
        # user2 active profile but unverified
        create(:profile, :active, :verified, user: user2)
        user2.profiles.first.deactivate(:password_reset)
      end
      let(:expected_total_count) { 2 }
      let(:expected_verified_legacy_idv_count) { 1 }
      let(:expected_verified_facial_match_count) { 0 }
      let(:expected_total_fully_registered) { 0 }
      let(:expected_new_count) { 2 }
      let(:expected_new_verified_legacy_idv_count) { 1 }
      let(:expected_new_verified_facial_match_count) { 0 }
      let(:expected_annual_count) { expected_total_count }
      let(:expected_annual_verified_legacy_idv_count) { 1 }
      let(:expected_annual_verified_facial_match_count) { 0 }

      it_behaves_like 'a report with the specified counts'
    end

    context 'with one facial match verified and one non-verified user' do
      before do
        user1 = create(:user)
        user2 = create(:user)
        create(:profile, :active, :facial_match_proof, user: user1)
        create(:profile, :active, :verified, user: user2)
        user2.profiles.first.deactivate(:password_reset)
      end
      let(:expected_total_count) { 2 }
      let(:expected_verified_legacy_idv_count) { 0 }
      let(:expected_verified_facial_match_count) { 1 }
      let(:expected_total_fully_registered) { 0 }
      let(:expected_new_count) { 2 }
      let(:expected_new_verified_legacy_idv_count) { 0 }
      let(:expected_new_verified_facial_match_count) { 1 }
      let(:expected_annual_count) { expected_total_count }
      let(:expected_annual_verified_legacy_idv_count) { 0 }
      let(:expected_annual_verified_facial_match_count) { 1 }

      it_behaves_like 'a report with the specified counts'
    end

    # The suspended and fraud-rejection examples are meant to highlight this
    # developer's understanding of the requirements and resulting behavior,
    # not to express immutable business logic.
    context 'with one user, who is suspended' do
      before { create(:user, :suspended) }

      # A suspended user is still a total user:
      let(:expected_total_count) { 1 }
      let(:expected_verified_legacy_idv_count) { 0 }
      let(:expected_verified_facial_match_count) { 0 }
      let(:expected_total_fully_registered) { 0 }
      let(:expected_new_count) { 1 }
      let(:expected_new_verified_legacy_idv_count) { 0 }
      let(:expected_new_verified_facial_match_count) { 0 }
      let(:expected_annual_count) { 1 }
      let(:expected_annual_verified_legacy_idv_count) { 0 }
      let(:expected_annual_verified_facial_match_count) { 0 }

      it_behaves_like 'a report with the specified counts'
    end

    context 'with one user, who was rejected for fraud' do
      before { create(:user, :fraud_rejection) }

      # A user with a fraud rejection is still a total user
      let(:expected_total_count) { 1 }
      let(:expected_verified_legacy_idv_count) { 0 }
      let(:expected_verified_facial_match_count) { 0 }
      let(:expected_total_fully_registered) { 1 }
      let(:expected_new_count) { 1 }
      let(:expected_new_verified_legacy_idv_count) { 0 }
      let(:expected_new_verified_facial_match_count) { 0 }
      let(:expected_annual_count) { 1 }
      let(:expected_annual_verified_legacy_idv_count) { 0 }
      let(:expected_annual_verified_facial_match_count) { 0 }

      it_behaves_like 'a report with the specified counts'
    end

    context 'with fully registered user' do
      before do
        create(:user)
        create_list(:user, 2).each do |user|
          RegistrationLog.create(user: user, registered_at: user.created_at)
        end
      end
      let(:expected_total_count) { 3 }
      let(:expected_verified_legacy_idv_count) { 0 }
      let(:expected_verified_facial_match_count) { 0 }
      let(:expected_total_fully_registered) { 2 }
      let(:expected_new_count) { 3 }
      let(:expected_new_verified_legacy_idv_count) { 0 }
      let(:expected_new_verified_facial_match_count) { 0 }
      let(:expected_annual_count) { 3 }
      let(:expected_annual_verified_legacy_idv_count) { 0 }
      let(:expected_annual_verified_facial_match_count) { 0 }

      it_behaves_like 'a report with the specified counts'
    end
  end
end
