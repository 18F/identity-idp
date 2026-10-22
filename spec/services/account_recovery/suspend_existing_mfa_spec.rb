require 'rails_helper'

RSpec.describe AccountRecovery::SuspendExistingMfa do
  let(:user) { create(:user, :fully_registered) }
  let(:recovery_request) { create(:account_recovery_request, :password_verified, user: user) }
  subject(:service) { described_class.new(account_recovery_request: recovery_request) }

  before do
    create(:auth_app_configuration, user: user)
    create(:webauthn_configuration, user: user)
    create(:piv_cac_configuration, user: user)
    create(:backup_code_configuration, user: user)
    user.create_direct_otp
  end

  it 'retains and suspends every old credential, revokes remembered devices, and clears OTP' do
    service.call

    described_class::CONFIGURATION_ASSOCIATIONS.each do |association|
      expect(user.public_send(association)).not_to be_empty
      expect(user.public_send(association).pluck(:account_recovery_request_id).uniq)
        .to eq([recovery_request.id])
    end
    expect(MfaContext.new(user).two_factor_enabled?).to eq(false)
    expect(user.reload.remember_device_revoked_at).to be_present
    expect(user.direct_otp).to be_nil
    expect(recovery_request.reload).to be_replacement_mfa_pending
  end

  it 'does not suspend a replacement on a repeated call' do
    service.call
    replacement = create(:webauthn_configuration, user: user)

    expect(service.call).to eq(false)
    expect(replacement.reload.account_recovery_request_id).to be_nil
  end

  it 'does nothing before password verification' do
    recovery_request.update!(state: AccountRecoveryRequest::LINK_VERIFIED)

    expect(service.call).to eq(false)
    expect(user.phone_configurations.first.account_recovery_request_id).to be_nil
  end

  it 'rolls suspension back if the state transition fails' do
    allow(recovery_request).to receive(:transition_to!).and_raise(ActiveRecord::RecordInvalid)

    expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.phone_configurations.first.reload.account_recovery_request_id).to be_nil
  end
end
