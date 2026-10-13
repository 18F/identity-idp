require 'rails_helper'

RSpec.describe TwoFactorAuthenticatableMethods do
  let(:user) { create(:user, :fully_registered) }
  let(:recovery_request) { create(:account_recovery_request, :password_verified, user: user) }

  controller(ApplicationController) {}

  before do
    stub_sign_in_before_2fa(user)
    AccountRecovery::SuspendExistingMfa.new(account_recovery_request: recovery_request).call
  end

  it 'does not let normal MFA authentication mark a recovery session authenticated' do
    controller.send(
      :mark_user_session_authenticated, auth_method: 'sms',
                                        authentication_type: :valid_2fa
    )

    expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq(true)
    expect(recovery_request.reload).to be_replacement_mfa_pending
  end

  it 'completes recovery before authenticating the replacement enrollment session' do
    create(:auth_app_configuration, user: user)

    controller.send(:handle_valid_verification_for_confirmation_context, auth_method: 'totp')

    expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::COMPLETED)
    expect(user.reload.phone_configurations).to be_empty
    expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq(false)
  end

  it 'keeps the remaining selections so enrollment continues after completion' do
    create(:auth_app_configuration, user: user)
    controller.user_session[:mfa_selections] = %w[auth_app backup_code]
    controller.user_session[:next_mfa_selection_choice] = 'auth_app'

    controller.send(:handle_valid_verification_for_confirmation_context, auth_method: 'totp')

    expect(controller.user_session[:account_recovery_completed]).to eq(true)
    expect(controller.user_session[:mfa_selections]).to eq(%w[auth_app backup_code])
    expect(controller.send(:next_setup_path)).to eq(controller.backup_code_setup_url)
    expect(controller.user_session[:account_recovery_completed]).to eq(true)

    controller.user_session[:next_mfa_selection_choice] = 'backup_code'
    expect(controller.send(:next_setup_path)).to eq(controller.account_url)
    expect(controller.user_session[:account_recovery_completed]).to be_nil
    expect(controller.user_session[:mfa_selections]).to be_nil
    expect(controller.flash[:success]).to eq(t('account_recovery.new_mfa_setup.completed_html'))
  end

  it 'fails closed when the replacement was not persisted' do
    expect do
      controller.send(:handle_valid_verification_for_confirmation_context, auth_method: 'totp')
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(controller.user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION]).to eq(true)
    expect(user.reload.phone_configurations).not_to be_empty
  end
end
