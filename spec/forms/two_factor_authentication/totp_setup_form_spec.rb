require 'rails_helper'

describe TwoFactorAuthentication::TotpSetupForm do
  let(:user) { create(:user) }
  let(:secret) { user.generate_totp_secret }
  let(:code) { generate_totp_code(secret) }
  let(:configuration_manager) do
    user.two_factor_method_manager.configuration_manager(:totp)
  end

  let(:form) do
    described_class.new(
      user: user,
      configuration_manager: configuration_manager,
      secret: secret,
      code: code
    )
  end

  describe '#submit' do
    context 'when TOTP code is valid' do
      it 'returns FormResponse with success: true' do
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}).and_return(result)
        expect(Event).to receive(:create).
          with(user_id: user.id, event_type: :authenticator_enabled)
        expect(form.submit).to eq result
        expect(user.reload.totp_enabled?).to eq true
      end
    end

    context 'when TOTP code is invalid' do
      let(:code) { 'kode' }
      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}).and_return(result)
        expect(Event).to_not receive(:create)
        expect(form.submit).to eq result
        expect(user.reload.totp_enabled?).to eq false
      end
    end
  end
end
