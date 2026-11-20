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

  it 'reports the removed method types for notification and analytics' do
    create(:auth_app_configuration, user: user)

    expect(service.removed_mfa_method_counts).to eq({})

    service.call

    expect(service.removed_mfa_method_counts).to eq({ phone: 1 })
  end

  it 'counts each removed configuration of the same type' do
    suspended_auth_apps = Array.new(2) do |index|
      create(:auth_app_configuration, user: user, name: "suspended #{index}")
    end
    suspended_auth_apps.each do |configuration|
      configuration.update!(account_recovery_request_id: recovery_request.id)
    end
    create(:auth_app_configuration, user: user, name: 'replacement')

    service.call

    expect(service.removed_mfa_method_counts).to eq({ phone: 1, auth_app: 2 })
  end

  it 'reports no removed methods when nothing was suspended' do
    user.phone_configurations.update_all(account_recovery_request_id: nil)
    create(:auth_app_configuration, user: user)

    expect(service.call).to eq(true)
    expect(service.removed_mfa_method_counts).to eq({})
  end

  it 'is a no-op once the request is no longer awaiting replacement MFA' do
    replacement = create(:auth_app_configuration, user: user)
    service.call

    expect(service.call).to eq(false)
    expect(replacement.class.exists?(replacement.id)).to eq(true)
  end

  it 'keeps the removed counts from the successful call after a no-op' do
    create(:auth_app_configuration, user: user)
    service.call

    expect(service.call).to eq(false)
    expect(service.removed_mfa_method_counts).to eq({ phone: 1 })
  end

  it 'rolls deletion back if completion fails' do
    allow(recovery_request).to receive(:transition_to!).and_raise(ActiveRecord::RecordInvalid)

    expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.phone_configurations).not_to be_empty
  end
end
