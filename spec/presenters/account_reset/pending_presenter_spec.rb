require 'rails_helper'

describe AccountReset::PendingPresenter do
  include ActionView::Helpers::TranslationHelper

  describe '#account_reset_request' do
    it 'returns account reset request' do
      requested_at = Time.zone.now
      account_reset_request = AccountResetRequest.new(user_id: 1, requested_at: requested_at)
      presenter = described_class.new(account_reset_request)
      expect(presenter.account_reset_request.requested_at).to eq requested_at
    end
  end

  describe '#time_remaining_until_granted' do
    let(:hour) { t('time.hour') }
    let(:hours) { t('time.hours') }
    let(:minute) { t('time.minute') }
    let(:minutes) { t('time.minutes') }
    let(:second) { t('time.second') }
    let(:seconds) { t('time.seconds') }

    before { Timecop.freeze Time.zone.now }
    after { Timecop.return }

    it 'returns time description in hours and minutes' do
      requested_at = Time.zone.now - 20.5.hours
      account_reset_request = AccountResetRequest.new(user_id: 1, requested_at: requested_at)
      presenter = described_class.new(account_reset_request)
      expect(presenter.time_remaining_until_granted).to eq "3 #{hours} and 30 #{minutes}"

      requested_at = Time.zone.now - 22.5.hours
      account_reset_request = AccountResetRequest.new(user_id: 1, requested_at: requested_at)
      presenter = described_class.new(account_reset_request)
      expect(presenter.time_remaining_until_granted).to eq "1 #{hour} and 30 #{minutes}"
    end

    it 'returns time description in hours and minutes, excluding seconds' do
      requested_at = Time.zone.now - 20.hours - 3.seconds
      account_reset_request = AccountResetRequest.new(user_id: 1, requested_at: requested_at)
      presenter = described_class.new(account_reset_request)
      expect(presenter.time_remaining_until_granted).to eq "3 #{hours} and 59 #{minutes}"
    end

    it 'returns time description in minutes and seconds' do
      requested_at = Time.zone.now - 24.hours + 70.seconds
      account_reset_request = AccountResetRequest.new(user_id: 1, requested_at: requested_at)
      presenter = described_class.new(account_reset_request)
      expect(presenter.time_remaining_until_granted).to eq "1 #{minute} and 10 #{seconds}"
    end

    it 'returns time description in seconds' do
      requested_at = Time.zone.now - 24.hours + 30.seconds
      account_reset_request = AccountResetRequest.new(user_id: 1, requested_at: requested_at)
      presenter = described_class.new(account_reset_request)
      expect(presenter.time_remaining_until_granted).to eq "30 #{seconds}"
    end

    it 'returns time description as 1 second' do
      requested_at = Time.zone.now - 24.hours + 1.second
      account_reset_request = AccountResetRequest.new(user_id: 1, requested_at: requested_at)
      presenter = described_class.new(account_reset_request)
      expect(presenter.time_remaining_until_granted).to eq "1 #{second}"
    end

    it 'returns time description as 1 second even if the remaining time is less than 1 second' do
      requested_at = Time.zone.now - 24.hours + 0.5.seconds
      account_reset_request = AccountResetRequest.new(user_id: 1, requested_at: requested_at)
      presenter = described_class.new(account_reset_request)
      expect(presenter.time_remaining_until_granted).to eq "1 #{second}"
    end
  end
end
