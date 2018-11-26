require 'rails_helper'

describe PersonalKeyForm do
  describe '#submit' do
    context 'when the form is valid' do
      it 'returns FormResponse with success: true' do
        user = create(:user)
        raw_code = PersonalKeyGenerator.new(user).create
        old_code = user.reload.encrypted_recovery_code_digest

        form = PersonalKeyForm.new(user, raw_code)
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'personal key' }

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.reload.encrypted_recovery_code_digest).to eq old_code
      end

      it 'sends an email and SMS notification to the user' do
        user = create(
          :user,
          :with_phone,
          email: 'jonny.hoops@gsa.gov',
          with: { phone: '+1 (202) 345-6789' }
        )
        raw_code = PersonalKeyGenerator.new(user).create

        personal_key_sign_in_mail = double
        expect(personal_key_sign_in_mail).to receive(:deliver_now)
        expect(UserMailer).to receive(:personal_key_sign_in).
          with('jonny.hoops@gsa.gov').
          and_return(personal_key_sign_in_mail)
        expect(SmsPersonalKeySignInNotifierJob).to receive(:perform_now).
          with(phone: '+1 (202) 345-6789')

        PersonalKeyForm.new(user, raw_code).submit
      end
    end

    context 'when the form is invalid' do
      it 'returns FormResponse with success: false' do
        user = create(:user, :signed_up, personal_key: 'code')
        errors = { personal_key: ['Incorrect personal key'] }

        form = PersonalKeyForm.new(user, 'foo')
        result = instance_double(FormResponse)
        extra = { multi_factor_auth_method: 'personal key' }

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors, extra: extra).and_return(result)
        expect(form.submit).to eq result
        expect(user.encrypted_recovery_code_digest).to_not be_nil
        expect(form.personal_key).to be_nil
      end
    end
  end
end
