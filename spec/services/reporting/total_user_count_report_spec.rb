require 'rails_helper'
require 'csv'

RSpec.describe Reporting::TotalUserCountReport do
  let(:report_date) do
    Date.new(2021, 3, 1).in_time_zone('UTC')
  end
  let(:expected_report) do
    [
      ['All-time user count'],
      [expected_count],
    ]
  end

  subject(:report) { described_class.new(report_date) }

  before { travel_to report_date }

  describe '#total_user_count_report' do
    shared_examples 'a report with that user counted' do
      let(:expected_count) { 1 }
      it 'includes that user in the count' do
        expect(subject.total_user_count_report).to eq expected_report
      end
    end

    context 'with no users' do
      let(:expected_count) { 0 }

      it 'returns a report with a count of zero' do
        expect(subject.total_user_count_report).to eq expected_report
      end
    end

    context 'with one ordinary user' do
      let!(:user) { create(:user) }
      it_behaves_like 'a report with that user counted'
    end

    context 'with a suspended user' do
      let!(:suspended_user) { create(:user, :suspended) }

      it 'has a suspended user' do
        expect(suspended_user).to be_suspended
        expect(User.count).to eq 1
      end

      it_behaves_like 'a report with that user counted'
    end

    context 'with an unconfirmed user' do
      let!(:unconfirmed_user) { create(:user, :unconfirmed) }

      it 'has an unconfirmed user' do
        expect(unconfirmed_user).to_not be_confirmed
        expect(User.count).to eq 1
      end

      it_behaves_like 'a report with that user counted'
    end

    context 'with a user rejected for fraud' do
      let!(:fraud_user) { create(:user, :fraud_rejection) }

      it 'has a user rejected for fraud' do
        expect(fraud_user).to be_fraud_rejection
        expect(User.count).to eq 1
      end

      it_behaves_like 'a report with that user counted'
    end
  end

  describe '#total_verified_user_report' do
    let(:expected_count) { 0 }
    let(:expected_report) do
      [['Total verified users'], [expected_count]]
    end

    context 'with only a non-IdV user' do
      let!(:unverified_user) { create(:user) }
      let(:expected_count) { 0 }

      it 'returns zero users' do
        expect(subject.total_verified_users_report).to eq expected_report
      end
    end

    context 'with an IdV user and a non-IdV user' do
      let!(:unverified_user) { create(:user) }
      let!(:verified_user) { create(:user, :proofed) }
      let(:expected_count) { 1 }

      it 'returns only 1 user (the IdV user)' do
        expect(subject.total_verified_users_report).to eq expected_report
      end
    end
  end
end
