require 'rails_helper'

describe TotpSetupForm do
  let(:user) { build_stubbed(:user) }
  let(:secret) { user.generate_totp_secret }
  let(:code) { generate_totp_code(secret) }

  describe '#submit' do
    context 'when TOTP code is valid' do
      it 'sets success to true' do
        form = TotpSetupForm.new(user, secret, code)

        result = {
          success: true
        }

        expect(form.submit).to eq result
      end
    end

    context 'when TOTP code is invalid' do
      it 'sets success to false' do
        form = TotpSetupForm.new(user, secret, 'kode')

        result = {
          success: false
        }

        expect(form.submit).to eq result
      end
    end
  end
end
