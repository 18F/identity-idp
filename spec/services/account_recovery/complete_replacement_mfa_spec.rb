require 'rails_helper'

RSpec.describe AccountRecovery::CompleteReplacementMfa do
  let(:user) { create(:user, :fully_registered) }
  let(:recovery_request) { create(:account_recovery_request, :password_verified, user: user) }

  before do
    AccountRecovery::SuspendExistingMfa.new(account_recovery_request: recovery_request).call
  end

  def complete(auth_method)
    described_class.new(account_recovery_request: recovery_request, auth_method: auth_method).call
  end

  {
    'sms' => :phone_configuration,
    'voice' => :phone_configuration,
    'totp' => :auth_app_configuration,
    'webauthn' => :webauthn_configuration,
    'piv_cac' => :piv_cac_configuration,
    'backup_code' => :backup_code_configuration,
  }.each do |auth_method, factory|
    it "preserves the #{auth_method} replacement and deletes only suspended credentials" do
      replacement = create(factory, user: user)
      old_phone = user.phone_configurations
        .where(account_recovery_request_id: recovery_request.id).first

      expect(complete(auth_method)).to eq(true)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::COMPLETED)
      expect(recovery_request.completed_at).to be_present
      expect(PhoneConfiguration.exists?(old_phone.id)).to eq(false)
      expect(replacement.class.exists?(replacement.id)).to eq(true)
      expect(complete(auth_method)).to eq(false)
      expect(replacement.class.exists?(replacement.id)).to eq(true)
    end
  end

  it 'supports a platform passkey replacement' do
    replacement = create(:webauthn_configuration, user: user, platform_authenticator: true)

    expect(complete('webauthn_platform')).to eq(true)
    expect(replacement.reload).to be_mfa_enabled
  end

  it 'does not complete or delete anything without a replacement' do
    expect(complete('totp')).to eq(false)
    expect(recovery_request.reload).to be_replacement_mfa_pending
    expect(user.phone_configurations).not_to be_empty
  end

  it 'rejects an unsupported authentication method' do
    expect(complete('remember_device')).to eq(false)
    expect(recovery_request.reload).to be_replacement_mfa_pending
  end

  it 'rolls deletion back if completion fails' do
    create(:auth_app_configuration, user: user)
    allow(recovery_request).to receive(:transition_to!).and_raise(ActiveRecord::RecordInvalid)

    expect { complete('totp') }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.phone_configurations).not_to be_empty
  end
end
