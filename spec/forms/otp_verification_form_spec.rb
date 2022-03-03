require 'rails_helper'

RSpec.describe OtpVerificationForm do
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        user = build_stubbed(:user)
        code = '123456'
        form = OtpVerificationForm.new(user, code)

        allow(user).to receive(:authenticate_direct_otp).with(code).and_return(true)

        expect(form.submit.to_h).to eq(
          success: true,
          errors: {},
          multi_factor_auth_method: 'otp_code',
        )
      end
    end

    context 'when the form is invalid' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user)
        code = '123456'
        form = OtpVerificationForm.new(user, code)

        expect(form.submit.to_h).to eq(
          success: false,
          errors: {},
          multi_factor_auth_method: 'otp_code',
        )
      end
    end

    context 'when the format of the code is not exactly 8 characters' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user)
        invalid_codes = [
          '123abcd11',
          '12345678',
          'abcdefg',
          "aaaaa\n123456\naaaaaaaaa",
        ]

        invalid_codes.each do |code|
          form = OtpVerificationForm.new(user, code)
          result = instance_double(FormResponse)
          allow(user).to receive(:authenticate_direct_otp).with(code).and_return(true)

          result = FormResponse.new(
            success: false,
            errors: {},
            extra: { multi_factor_auth_method: 'otp_code' },
          )

          expect(form.submit).to eq(result), "expected #{code.inspect} to not pass"
        end
      end
    end
  end
end
