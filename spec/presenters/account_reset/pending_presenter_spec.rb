require 'rails_helper'

describe AccountReset::PendingPresenter do
  let(:user) { create(:user) }
  let(:hours) { 21 }
  let(:minutes) { 13 }
  let(:seconds) { 40 }
  let(:requested_at) do
    24.hours.ago + hours.hours + minutes.minutes + seconds.seconds
  end
  let(:account_reset_request) do
    AccountResetRequest.new(
      user: user,
      requested_at: requested_at,
    )
  end

  subject { described_class.new(account_reset_request) }

  describe '#account_reset_request' do
    it 'returns account reset request' do
      expect(subject.account_reset_request.requested_at).to eq(requested_at)
    end
  end

  describe '#time_remaining_until_granted' do
    around(:each) do |example|
      I18n.locale = :en
      Timecop.freeze Time.zone.now do
        example.run
      end
    end

    context 'when requested at is greater than an hour' do
      it 'returns the description in hours and minutes' do
        expect(subject.time_remaining_until_granted).to eq '21 hours and 13 minutes'
      end
    end

    context 'when requested at is greater than a minute' do
      let(:hours) { 0 }

      it 'returns the description in minutes and seconds' do
        expect(subject.time_remaining_until_granted).to eq '13 minutes and 40 seconds'
      end
    end

    context 'when requested at is less than a minute' do
      let(:hours) { 0 }
      let(:minutes) { 0 }

      it 'returns the description in minutes and seconds' do
        expect(subject.time_remaining_until_granted).to eq '40 seconds'
      end
    end

    context 'when the request is less than a second' do
      let(:hours) { 0 }
      let(:minutes) { 0 }
      let(:seconds) { 0 }

      it 'returns the description in minutes and seconds' do
        expect(subject.time_remaining_until_granted).to eq 'less than 1 second'
      end
    end
  end
end
