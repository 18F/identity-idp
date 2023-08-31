require 'rails_helper'

RSpec.describe TotpVerificationForm do
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        user = create(:user, :with_authentication_app)
        code = '123456'
        form = TotpVerificationForm.new(user, code)

        cfg = user.auth_app_configurations.first
        allow(Db::AuthAppConfiguration).to receive(:authenticate).and_return(cfg)

        expect(form.submit.to_h).to eq(
          success: true,
          errors: {},
          multi_factor_auth_method: 'totp',
          auth_app_configuration_id: cfg.id,
          multi_factor_auth_method_created_at: cfg.created_at.strftime('%s%L'),
        )
      end
    end

    context 'when the form is invalid' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user)
        code = '123456'
        form = TotpVerificationForm.new(user, code)

        allow(user).to receive(:authenticate_totp).and_return(false)

        expect(form.submit.to_h).to eq(
          success: false,
          errors: {},
          multi_factor_auth_method: 'totp',
          auth_app_configuration_id: nil,
          multi_factor_auth_method_created_at: nil,
        )
      end
    end

    context 'when the format of the code is not exactly 6 digits' do
      it 'returns FormResponse with success: false' do
        user = build_stubbed(:user)
        invalid_codes = %W[123abc 1234567 abcdef aaaaa\n123456\naaaaaaaaa]

        invalid_codes.each do |code|
          form = TotpVerificationForm.new(user, code)
          allow(user).to receive(:authenticate_totp).with(code).and_return(true)

          expect(form.submit.to_h).to eq(
            success: false,
            errors: {},
            multi_factor_auth_method: 'totp',
            auth_app_configuration_id: nil,
            multi_factor_auth_method_created_at: nil,
          )
        end
      end
    end
  end
end
