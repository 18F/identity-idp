# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reporting::TotalUserCountReport do
  let(:report_date) { Time.zone.today + 1.day }
  let!(:user) { create(:user) }
  let(:expected_report) do
    [
      ['All-time user count'],
      [expected_count],
    ]
  end

  subject { described_class.new(report_date) }

  describe '#total_user_count_report' do
    let(:expected_count) { 1 }

    it 'returns the expected data' do
      expect(subject.total_user_count_report).to eq(expected_report)
    end

    context 'with a suspended user' do
      let(:suspended_user) { create(:user, :suspended) }
      let(:expected_count) { 2 }

      it 'includes the suspended user in the count' do
        expect(suspended_user).to be_suspended
        expect(subject.total_user_count_report).to eq(expected_report)
      end
    end

    context 'with an unconfirmed user' do
      let(:unconfirmed_user) { create(:user, :unconfirmed) }
      let(:expected_count) { 2 }

      it 'includes the unconfirmed user in the count' do
        expect(unconfirmed_user).not_to be_confirmed
        expect(subject.total_user_count_report).to eq(expected_report)
      end
    end

    context 'with a user rejected for fraud' do
      let(:fraud_user) { create(:user, :fraud_rejection) }
      let(:expected_count) { 2 }

      it 'includes them in the count because they are still a user' do
        expect(fraud_user).to be_fraud_rejection
        expect(subject.total_user_count_report).to eq(expected_report)
      end
    end
  end
end
