require 'rails_helper'

RSpec.describe AccountRecovery::PendingPresenter do
  let(:now) { Time.zone.now }
  let(:recovery_request) do
    build(:account_recovery_request, :waiting, requested_at: now - 6.hours)
  end

  subject(:presenter) { described_class.new(recovery_request) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days).and_return(1)
  end

  describe '#time_remaining_until_granted' do
    it 'reports the time left in the waiting period' do
      expect(presenter.time_remaining_until_granted(now:)).to eq('18 hours')
    end

    it 'does not report elapsed time once the waiting period has passed' do
      recovery_request.requested_at = now - 2.days

      expect(presenter.time_remaining_until_granted(now:)).to eq('1 minute')
    end
  end

  describe '#waiting_period' do
    it 'formats the configured waiting period' do
      expect(presenter.waiting_period).to eq('24 hours')
    end
  end

  describe '#granted?' do
    it 'is false while waiting' do
      expect(presenter.granted?).to be(false)
    end

    it 'is true once granted' do
      recovery_request.state = AccountRecoveryRequest::GRANTED

      expect(presenter.granted?).to be(true)
    end
  end
end
