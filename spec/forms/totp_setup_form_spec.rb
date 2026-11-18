require 'rails_helper'

RSpec.describe TotpSetupForm do
  let(:user) { create(:user) }
  let(:secret) { user.generate_totp_secret }
  let(:code) { generate_totp_code(secret) }
  let(:name) { SecureRandom.hex[0, 19] }

  describe '#submit' do
    context 'when TOTP code is valid' do
      it 'returns FormResponse with success: true' do
        form = TotpSetupForm.new(user, secret, code, name)
        extra = {
          totp_secret_present: true,
          multi_factor_auth_method: 'totp',
          auth_app_configuration_id: next_auth_app_id,
          enabled_mfa_methods_count: 1,
        }

        expect(form.submit.to_h).to eq(
          success: true,
          **extra,
        )
        expect(user.auth_app_configurations.any?).to eq true
      end
    end

    context 'when TOTP code is invalid' do
      it 'returns FormResponse with success: false' do
        form = TotpSetupForm.new(user, secret, 'kode', name)
        extra = {
          totp_secret_present: true,
          multi_factor_auth_method: 'totp',
          auth_app_configuration_id: nil,
        }

        expect(form.submit.to_h).to include(
          success: false,
          **extra,
        )
        expect(user.auth_app_configurations.any?).to eq false
      end
    end

    # We've seen a few cases in production where the authentication app
    # setup page was submitted without a secret_key in the user_session
    context 'when the secret key is not present' do
      it 'returns FormResponse with success: false' do
        form = TotpSetupForm.new(user, nil, 'kode', name)
        extra = {
          totp_secret_present: false,
          multi_factor_auth_method: 'totp',
          auth_app_configuration_id: nil,
        }

        expect(form.submit.to_h).to include(
          success: false,
          **extra,
        )
        expect(user.auth_app_configurations.any?).to eq false
      end
    end

    context 'when name is empty' do
      let(:name) { '' }

      it 'returns an unsuccessful form response' do
        form = TotpSetupForm.new(user, secret, code, name)

        expect(form.submit.to_h).to include(
          success: false,
          error_details: { name: { blank: true } },
        )
        expect(user.auth_app_configurations.any?).to eq false
      end
    end

    context 'when name is not unique' do
      it 'returns an unsuccessful form response' do
        form1 = TotpSetupForm.new(user, secret, code, name)
        form1.submit
        form2 = TotpSetupForm.new(user, secret, code, name)

        expect(form2.submit.to_h).to include(
          success: false,
          error_details: { name: { unique_name: true } },
        )
      end
    end

    context 'when the name is held by a configuration suspended for account recovery' do
      let(:user) { create(:user, :fully_registered) }

      it 'releases the suspended configuration and reuses the name' do
        suspended = create(:auth_app_configuration, user: user, name: name)
        recovery_request = create(
          :account_recovery_request,
          :replacement_mfa_pending,
          user: user,
        )
        suspended.update!(account_recovery_request_id: recovery_request.id)

        form = TotpSetupForm.new(user, secret, code, name)

        expect(form.submit).to be_success
        expect(AuthAppConfiguration.exists?(suspended.id)).to eq(false)
        expect(user.auth_app_configurations.reload.map(&:name)).to eq([name])
      end

      it 'still rejects the name when the configuration is not suspended' do
        create(:auth_app_configuration, user: user, name: name)

        form = TotpSetupForm.new(user, secret, code, name)

        expect(form.submit.to_h).to include(
          success: false,
          error_details: { name: { unique_name: true } },
        )
      end

      it 'keeps the suspended configuration when the code is invalid' do
        suspended = create(:auth_app_configuration, user: user, name: name)
        recovery_request = create(
          :account_recovery_request,
          :replacement_mfa_pending,
          user: user,
        )
        suspended.update!(account_recovery_request_id: recovery_request.id)

        form = TotpSetupForm.new(user, secret, 'invalid', name)

        expect(form.submit).to_not be_success
        expect(AuthAppConfiguration.exists?(suspended.id)).to eq(true)
      end
    end
  end

  def next_auth_app_id
    recs = ActiveRecord::Base.connection.execute(
      "SELECT NEXTVAL(pg_get_serial_sequence('auth_app_configurations', 'id')) AS new_id",
    )
    recs[0]['new_id'] + 1
  end
end
