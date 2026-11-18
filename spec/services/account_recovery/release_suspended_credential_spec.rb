require 'rails_helper'

RSpec.describe AccountRecovery::ReleaseSuspendedCredential do
  let(:user) { create(:user, :fully_registered) }
  let(:recovery_request) { create(:account_recovery_request, :password_verified, user: user) }

  subject(:service) do
    described_class.new(user: user, configuration: configuration)
  end

  def suspend_existing_mfa
    recovery_request.with_lock do
      AccountRecovery::SuspendExistingMfa.new(account_recovery_request: recovery_request).call
    end
  end

  context 'with a credential suspended by the user’s in-flight recovery' do
    let!(:configuration) do
      suspend_existing_mfa
      user.phone_configurations.reload.first
    end

    it 'reports the credential as releasable' do
      expect(service.releasable?).to eq(true)
    end

    it 'destroys the credential so the same one can be re-enrolled' do
      expect(service.call).to eq(true)
      expect(PhoneConfiguration.exists?(configuration.id)).to eq(false)
    end

    it 'releases an auth app configuration' do
      auth_app = create(:auth_app_configuration, user: user)
      auth_app.update!(account_recovery_request_id: recovery_request.id)

      expect(described_class.new(user: user, configuration: auth_app).call).to eq(true)
      expect(AuthAppConfiguration.exists?(auth_app.id)).to eq(false)
    end

    it 'exposes the configuration under test' do
      expect(service.configuration).to eq(configuration)
    end
  end

  context 'with a credential that is not suspended' do
    let!(:configuration) { user.phone_configurations.first }

    it 'leaves the credential alone so normal uniqueness errors still apply' do
      expect(service.releasable?).to eq(false)
      expect(service.call).to eq(false)
      expect(PhoneConfiguration.exists?(configuration.id)).to eq(true)
    end
  end

  context 'with another user’s suspended credential' do
    let(:other_user) { create(:user, :fully_registered) }
    let(:other_request) do
      create(:account_recovery_request, :password_verified, user: other_user)
    end
    let!(:configuration) do
      other_request.with_lock do
        AccountRecovery::SuspendExistingMfa.new(account_recovery_request: other_request).call
      end
      other_user.phone_configurations.reload.first
    end

    it 'refuses to release it' do
      expect(service.call).to eq(false)
      expect(PhoneConfiguration.exists?(configuration.id)).to eq(true)
    end
  end

  context 'when the recovery request is no longer awaiting replacement MFA' do
    let!(:configuration) do
      suspend_existing_mfa
      user.phone_configurations.reload.first
    end

    it 'refuses to release a credential for a cancelled request' do
      recovery_request.reload.cancel!(
        reason: AccountRecoveryRequest::CANCEL_REASON_USER_CANCELLED,
      )

      expect(service.call).to eq(false)
      expect(PhoneConfiguration.exists?(configuration.id)).to eq(true)
    end

    it 'refuses to release a credential for an expired request' do
      recovery_request.reload.expire!

      expect(service.call).to eq(false)
      expect(PhoneConfiguration.exists?(configuration.id)).to eq(true)
    end
  end

  context 'with a request still before password verification' do
    let(:recovery_request) { create(:account_recovery_request, :granted, user: user) }
    let!(:configuration) do
      user.phone_configurations.first.tap do |phone_configuration|
        phone_configuration.update!(account_recovery_request_id: recovery_request.id)
      end
    end

    it 'refuses to release the credential' do
      expect(service.call).to eq(false)
      expect(PhoneConfiguration.exists?(configuration.id)).to eq(true)
    end
  end

  context 'with no colliding configuration' do
    let(:configuration) { nil }

    it 'reports nothing was released' do
      expect(service.call).to eq(false)
    end
  end

  context 'with a record that cannot be suspended' do
    let(:configuration) { create(:email_address, user: user) }

    it 'reports nothing was released' do
      expect(service.call).to eq(false)
    end
  end
end
