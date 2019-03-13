require 'rails_helper'

describe TotpSetupForm do
  let(:user) { create(:user) }
  let(:secret) { user.generate_totp_secret }
  let(:code) { generate_totp_code(secret) }

  describe '#submit' do
    context 'when TOTP code is valid' do
      it 'returns FormResponse with success: true' do
        form = TotpSetupForm.new(user, secret, code)
        result = instance_double(FormResponse)
        extra = {
          totp_secret_present: true,
          multi_factor_auth_method: 'totp',
        }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.reload.totp_enabled?).to eq true
      end
    end

    context 'when TOTP code is invalid' do
      it 'returns FormResponse with success: false' do
        form = TotpSetupForm.new(user, secret, 'kode')
        result = instance_double(FormResponse)
        extra = {
          totp_secret_present: true,
          multi_factor_auth_method: 'totp',
        }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.reload.totp_enabled?).to eq false
      end
    end

    # We've seen a few cases in production where the authentication app
    # setup page was submitted without a secret_key in the user_session
    context 'when the secret key is not present' do
      it 'returns FormResponse with success: false' do
        form = TotpSetupForm.new(user, nil, 'kode')
        result = instance_double(FormResponse)
        extra = {
          totp_secret_present: false,
          multi_factor_auth_method: 'totp',
        }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.reload.totp_enabled?).to eq false
      end
    end
  end
end
