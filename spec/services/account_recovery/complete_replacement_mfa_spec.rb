require 'rails_helper'

RSpec.describe AccountRecovery::CompleteReplacementMfa do
  let(:user) { create(:user, :fully_registered) }
  let(:recovery_request) { create(:account_recovery_request, :password_verified, user: user) }
  subject(:service) { described_class.new(account_recovery_request: recovery_request) }

  before do
    recovery_request.with_lock do
      AccountRecovery::SuspendExistingMfa.new(account_recovery_request: recovery_request).call
    end
  end

  it 'deletes only the suspended credentials and completes the request' do
    replacement = create(:auth_app_configuration, user: user)
    old_phone = user.phone_configurations
      .where(account_recovery_request_id: recovery_request.id).first

    expect(service.call).to eq(true)
    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::COMPLETED)
    expect(recovery_request.completed_at).to be_present
    expect(PhoneConfiguration.exists?(old_phone.id)).to eq(false)
    expect(replacement.reload).to be_mfa_enabled
  end

  it 'is a no-op once the request is no longer awaiting replacement MFA' do
    replacement = create(:auth_app_configuration, user: user)
    service.call

    expect(service.call).to eq(false)
    expect(replacement.class.exists?(replacement.id)).to eq(true)
  end

  it 'rolls deletion back if completion fails' do
    allow(recovery_request).to receive(:transition_to!).and_raise(ActiveRecord::RecordInvalid)

    expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.phone_configurations).not_to be_empty
  end
end
