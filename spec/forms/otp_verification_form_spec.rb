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

    context 'when alphanumeric is enabled and the code is not exactly 6 characters' do
      it 'returns FormResponse with success: false' do
        allow(IdentityConfig.store).to receive(:enable_numeric_authentication_otp).and_return(false)
        user = build_stubbed(:user)
        invalid_codes = [
          '123abcd',
          '1234567',
          'abcde',
          "aaaaa\n123456\naaaaaaaaa",
        ]

        invalid_codes.each do |code|
          form = OtpVerificationForm.new(user, code)
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

    context 'when numeric is enabled and the code is not exactly 6 digits' do
      it 'returns FormResponse with success: false' do
        allow(IdentityConfig.store).to receive(:enable_numeric_authentication_otp).and_return(true)
        user = build_stubbed(:user)
        invalid_codes = [
          'abcdef',
          '12345a',
          "aaaaa\n123456\naaaaaaaaa",
        ]

        invalid_codes.each do |code|
          form = OtpVerificationForm.new(user, code)
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
