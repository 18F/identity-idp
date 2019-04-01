require 'rails_helper'

describe OtpVerificationForm do
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        user = build_stubbed(:user)
        code = '123456'
        form = OtpVerificationForm.new(user, code)
        result = instance_double(FormResponse)

        allow(user).to receive(:authenticate_direct_otp).with(code).and_return(true)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: { multi_factor_auth_method: 'otp_code' }).
          and_return(result)
        expect(form.submit).to eq result
      end
    end

    context 'when the form is invalid' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user)
        code = '123456'
        form = OtpVerificationForm.new(user, code)
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}, extra: { multi_factor_auth_method: 'otp_code' }).
          and_return(result)
        expect(form.submit).to eq result
      end
    end

    context 'when the format of the code is not exactly 6 digits' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user)
        invalid_codes = %W[123abc 1234567 abcdef aaaaa\n123456\naaaaaaaaa]

        invalid_codes.each do |code|
          form = OtpVerificationForm.new(user, code)
          result = instance_double(FormResponse)
          allow(user).to receive(:authenticate_direct_otp).with(code).and_return(true)

          expect(FormResponse).to receive(:new).
            with(success: false, errors: {}, extra: { multi_factor_auth_method: 'otp_code' }).
            and_return(result)
          expect(form.submit).to eq result
        end
      end
    end
  end
end
