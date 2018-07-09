require 'rails_helper'

describe TwoFactorAuthentication::VoiceVerifyForm do
  let(:user) { build_stubbed(:user) }
  let(:configuration_manager) do
    user.two_factor_method_manager.configuration_manager(:voice)
  end
  let(:code) { '123456' }

  let(:form) do
    described_class.new(
      user: user,
      configuration_manager: configuration_manager,
      code: code
    )
  end

  describe '#submit' do
    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        result = instance_double(FormResponse)

        allow(user).to receive(:authenticate_direct_otp).with(code).and_return(true)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}).
          and_return(result)
        expect(form.submit).to eq result
      end
    end

    context 'when the form is invalid' do
      it 'returns FormResponse with success: false' do
        result = instance_double(FormResponse)

        allow(user).to receive(:authenticate_direct_otp).with(code).and_return(false)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: {}).
          and_return(result)
        expect(form.submit).to eq result
      end
    end

    context 'when the format of the code is not exactly 6 digits' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user)
        invalid_codes = %W[123abc 1234567 abcdef aaaaa\n123456\naaaaaaaaa]

        invalid_codes.each do |code|
          form = described_class.new(
            user: user,
            configuration_manager: configuration_manager,
            code: code
          )
          result = instance_double(FormResponse)
          allow(user).to receive(:authenticate_direct_otp).with(code).and_return(true)

          expect(FormResponse).to receive(:new).
            with(success: false, errors: {}).
            and_return(result)
          expect(form.submit).to eq result
        end
      end
    end
  end
end
