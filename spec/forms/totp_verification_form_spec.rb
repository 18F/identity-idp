require 'rails_helper'

describe TotpVerificationForm do
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        user = build_stubbed(:user)
        code = '123456'
        form = TotpVerificationForm.new(user, code)
        result = instance_double(FormResponse)

        allow(user).to receive(:authenticate_totp).and_return(true)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: { multi_factor_auth_method: 'totp' }).
          and_return(result)
        expect(form.submit).to eq result
      end
    end

    context 'when the form is invalid' do
      it 'returns false' do
        user = build_stubbed(:user)
        code = '123456'
        form = TotpVerificationForm.new(user, code)
        result = instance_double(FormResponse)

        allow(user).to receive(:authenticate_totp).and_return(false)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: { multi_factor_auth_method: 'totp' }).
          and_return(result)
        expect(form.submit).to eq result
      end
    end
  end
end
