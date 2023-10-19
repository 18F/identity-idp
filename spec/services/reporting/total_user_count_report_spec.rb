require 'rails_helper'
require 'csv'

RSpec.describe Reporting::TotalUserCountReport do
  let(:report_date) do
    Date.new(2021, 3, 1).in_time_zone('UTC')
  end

  let(:expected_report) do
    [
      ['All-time user count', expected_total_count],
      ['Total verified users', expected_verified_count],
      ['Total annual users', expected_annual_count],
    ]
  end

  subject(:report) { described_class.new(report_date) }

  before { travel_to report_date }

  describe '#total_user_count_report' do
    shared_examples 'a report with the specified counts' do
      it 'returns a report with the expected counts' do
        expect(subject.total_user_count_report).to eq expected_report
      end
    end

    context 'with only a non-verified user' do
      before { create(:user) }
      let(:expected_total_count) { 1 }
      let(:expected_verified_count) { 0 }
      let(:expected_annual_count) { expected_total_count }

      it_behaves_like 'a report with the specified counts'
    end

    context 'with 2 users, 1 from more than a year ago' do
      let!(:recent_user) { create(:user) }
      let!(:old_user) { create(:user, created_at: report_date - 13.months) }

      let(:expected_total_count) { 2 }
      let(:expected_verified_count) { 0 }
      let(:expected_annual_count) { 1 }

      it_behaves_like 'a report with the specified counts'
    end

    context 'with one verified and one non-verified user' do
      before do
        create(:user)
        user2 = create(:user)
        # MW: The :verified trait doesn't set active: true. This feels confusing.
        create(:profile, :active, user: user2)
      end
      let(:expected_total_count) { 2 }
      let(:expected_verified_count) { 1 }
      let(:expected_annual_count) { expected_total_count }

      it_behaves_like 'a report with the specified counts'
    end

    # The suspended and fraud-rejection examples are meant to highlight this
    # developer's understanding of the requirements and resulting behavior,
    # not to express immutable business logic.
    context 'with one user, who is suspended' do
      before { create(:user, :suspended) }

      # A suspended user is still a total user:
      let(:expected_total_count) { 1 }
      let(:expected_verified_count) { 0 }
      let(:expected_annual_count) { 1 }

      it_behaves_like 'a report with the specified counts'
    end

    context 'with one user, who was rejected for fraud' do
      before { create(:user, :fraud_rejection) }

      # A user with a fraud rejection is still a total user
      let(:expected_total_count) { 1 }
      let(:expected_verified_count) { 0 }
      let(:expected_annual_count) { 1 }

      it_behaves_like 'a report with the specified counts'
    end
  end
end
