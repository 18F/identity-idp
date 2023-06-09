require 'rails_helper'

RSpec.describe PersonalKeyForm do
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        user = create(:user)
        raw_code = PersonalKeyGenerator.new(user).create
        old_code = user.reload.encrypted_recovery_code_digest

        form = PersonalKeyForm.new(user, raw_code)
        extra = { multi_factor_auth_method: 'personal key' }

        expect(form.submit.to_h).to eq(
          success: true,
          errors: {},
          **extra,
        )
        expect(user.reload.encrypted_recovery_code_digest).to eq old_code
      end
    end

    context 'when the form is invalid' do
      it 'returns FormResponse with success: false' do
        user = create(:user, :fully_registered, personal_key: 'code')
        errors = { personal_key: ['Incorrect personal key'] }

        form = PersonalKeyForm.new(user, 'foo')
        extra = { multi_factor_auth_method: 'personal key' }

        expect(form.submit.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
        expect(user.encrypted_recovery_code_digest).to_not be_nil
        expect(form.personal_key).to be_nil
      end
    end
  end
end
