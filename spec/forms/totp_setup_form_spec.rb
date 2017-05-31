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

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}).and_return(result)
        expect(Event).to receive(:create).
          with(user_id: user.id, event_type: :authenticator_enabled)
        expect(form.submit).to eq result
        expect(user.reload.totp_enabled?).to eq true
      end
    end

    context 'when TOTP code is invalid' do
      it 'returns FormResponse with success: false' do
        form = TotpSetupForm.new(user, secret, 'kode')
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
