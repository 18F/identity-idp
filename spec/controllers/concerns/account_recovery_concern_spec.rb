require 'rails_helper'

RSpec.describe AccountRecoveryConcern do
  let(:instance) { Class.new { include AccountRecoveryConcern }.new }

  describe '#account_recovery_wait_period_interval' do
    it 'uses the recovery wait period independently of the reset wait period' do
      allow(IdentityConfig.store).to receive(:account_recovery_wait_period_days).and_return(2)
      allow(IdentityConfig.store).to receive(:account_reset_wait_period_days).and_return(4)

      expect(instance.account_recovery_wait_period_interval).to eq('48 hours')
    end
  end
end
