require 'rails_helper'

RSpec.describe TwoFactorAuthenticatableMethods do
  let(:user) { create(:user, :fully_registered) }
  let(:recovery_request) { create(:account_recovery_request, :password_verified, user: user) }

  controller ApplicationController do; end

  before do
    stub_sign_in_before_2fa(user)
    AccountRecovery::SuspendExistingMfa.new(account_recovery_request: recovery_request).call
  end

  it 'does not let normal MFA authentication mark a recovery session authenticated' do
    controller.send(
      :mark_user_session_authenticated, auth_method: 'sms',
                                        authentication_type: :valid_2fa
    )

    expect(controller.user_fully_authenticated?).to eq(false)
    expect(recovery_request.reload).to be_replacement_mfa_pending
  end

  it 'completes recovery before authenticating the replacement enrollment session' do
    create(:auth_app_configuration, user: user)

    controller.send(:handle_valid_verification_for_confirmation_context, auth_method: 'totp')

    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::COMPLETED)
    expect(user.phone_configurations).to be_empty
    expect(controller.user_fully_authenticated?).to eq(true)
  end

  it 'fails closed when the replacement was not persisted' do
    expect do
      controller.send(:handle_valid_verification_for_confirmation_context, auth_method: 'totp')
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(controller.user_fully_authenticated?).to eq(false)
    expect(user.phone_configurations).not_to be_empty
  end
end
