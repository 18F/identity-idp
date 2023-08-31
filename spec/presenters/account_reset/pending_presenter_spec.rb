require 'rails_helper'

RSpec.describe AccountReset::PendingPresenter do
  let(:user) { create(:user) }
  let(:requested_at) { 22.hours.ago }
  let(:account_reset_request) do
    AccountResetRequest.new(
      user: user,
      requested_at: requested_at,
    )
  end

  subject { described_class.new(account_reset_request) }

  describe '#account_reset_request' do
    it 'returns the account reset request' do
      expect(subject.account_reset_request.requested_at).to eq(requested_at)
    end
  end

  describe '#time_remaining_until_granted' do
    before { I18n.locale = :en }

    context 'when the remaining time is greater than 1 hour' do
      let(:requested_at) { 24.hours.ago - (2.hours + 21.minutes) }

      it 'returns its description in hours and minutes' do
        expect(subject.time_remaining_until_granted).to eq '2 hours and 21 minutes'
      end
    end

    context 'when the remaining time is less than 2 hours' do
      let(:requested_at) { 24.hours.ago - (1.hour + 49.minutes) }

      it 'returns its description in 1 hour and minutes' do
        expect(subject.time_remaining_until_granted).to eq '1 hour and 49 minutes'
      end
    end

    context 'when the remaining time is greater than 1 minute' do
      let(:requested_at) { 24.hours.ago - (13.minutes + 40.seconds) }

      it 'returns its description in minutes and seconds' do
        expect(subject.time_remaining_until_granted).to eq '13 minutes and 40 seconds'
      end
    end

    context 'when the remaining time is less than 2 minutes' do
      let(:requested_at) { 24.hours.ago - (1.minute + 25.seconds) }

      it 'returns its description in 1 minute and seconds' do
        expect(subject.time_remaining_until_granted).to eq '1 minute and 25 seconds'
      end
    end

    context 'when the remaining time is less than 1 minute' do
      let(:requested_at) { 24.hours.ago - 40.seconds }

      it 'returns its description in minutes and seconds' do
        expect(subject.time_remaining_until_granted).to eq '40 seconds'
      end
    end

    context 'when the remaining time is less than 1 second' do
      let(:requested_at) { 24.hours.ago - 0.5.seconds }

      it 'returns less than 1 second' do
        expect(subject.time_remaining_until_granted).to eq 'less than 1 second'
      end
    end
  end
end
