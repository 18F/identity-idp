require 'rails_helper'

RSpec.describe 'Suspended recovery credentials' do
  let(:user) { create(:user, :fully_registered) }
  let(:recovery_request) { create(:account_recovery_request, :replacement_mfa_pending, user: user) }

  it 'does not authenticate a suspended app with its otherwise valid TOTP' do
    secret = ROTP::Base32.random
    create(
      :auth_app_configuration, user: user, otp_secret_key: secret,
                               account_recovery_request_id: recovery_request.id
    )
    code = ROTP::TOTP.new(secret, interval: IdentityConfig.store.totp_code_interval).now

    expect(TotpVerificationForm.new(user, code).submit).not_to be_success
  end

  it 'does not consume a suspended backup code through the raw SQL verifier' do
    generator = BackupCodeGenerator.new(user)
    codes = generator.delete_and_regenerate
    user.backup_code_configurations.update_all(account_recovery_request_id: recovery_request.id)

    expect(generator.if_valid_consume_code_return_config_created_at(codes.first)).to be_nil
    expect(user.backup_code_configurations.where.not(used_at: nil)).to be_empty
    expect(BackupCodeConfiguration.find_with_code(code: codes.first, user_id: user.id)).to be_nil
  end

  it 'does not resolve a suspended PIV/CAC through the direct verification form' do
    configuration = create(
      :piv_cac_configuration, user: user,
                              account_recovery_request_id: recovery_request.id
    )
    form = UserPivCacVerificationForm.new(user: user, x509_dn_uuid: configuration.x509_dn_uuid)

    expect(form.piv_cac_configuration).to be_nil
  end

  it 'does not select a suspended default phone even when its ID is requested' do
    phone = user.phone_configurations.first
    phone.update!(account_recovery_request_id: recovery_request.id)

    expect(MfaContext.new(user).phone_configuration).to be_nil
    expect(MfaContext.new(user).phone_configuration(phone.id)).to be_nil
  end
end
