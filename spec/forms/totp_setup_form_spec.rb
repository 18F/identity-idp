require 'rails_helper'

describe TotpSetupForm do
  let(:user) { create(:user) }
  let(:secret) { user.generate_totp_secret }
  let(:code) { generate_totp_code(secret) }
  let(:name) { SecureRandom.hex }

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
          errors: {},
          **extra,
        )
        expect(user.auth_app_configurations.any?).to eq true
      end

      it 'sends a recovery information changed event' do
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryInformationChangedEvent.new(user: user))
        form = TotpSetupForm.new(user, secret, code, name)

        form.submit
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
          errors: {},
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
          errors: {},
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
          error_details: { name: [:blank] },
          errors: { name: [t('errors.messages.blank')] },
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
          error_details: { name: [t('errors.piv_cac_setup.unique_name')] },
          errors: { name: [t('errors.piv_cac_setup.unique_name')] },
        )
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
