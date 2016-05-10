require 'rails_helper'

describe UserProfileUpdater do
  let(:user) { build_stubbed(:user, :signed_up) }
  let(:form) { UpdateUserProfileForm.new(user) }

  describe '#send_notifications' do
    context 'when email is already taken' do
      it 'sends an email to the user who already has that email' do
        allow(form).to receive(:errors).
          and_return(email: [t('errors.messages.taken')])

        mailer = instance_double(ActionMailer::MessageDelivery)
        expect(UserMailer).to receive(:signup_with_your_email).with(form.email).
          and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        UserProfileUpdater.new(form).send_notifications
      end
    end

    context 'when mobile is already taken' do
      it 'sends an SMS to the existing user' do
        allow(form).to receive(:errors).
          and_return(mobile: [t('errors.messages.taken')])

        expect(SmsSenderExistingMobileJob).to receive(:perform_later).
          with(form.mobile)

        UserProfileUpdater.new(form).send_notifications
      end
    end

    context 'when both email and mobile are already taken' do
      it 'sends an email and SMS to the existing user' do
        allow(form).to receive(:errors).
          and_return(mobile: [t('errors.messages.taken')],
                     email: [t('errors.messages.taken')])

        mailer = instance_double(ActionMailer::MessageDelivery)
        expect(UserMailer).to receive(:signup_with_your_email).
          with(form.email).and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        expect(SmsSenderExistingMobileJob).to receive(:perform_later).
          with(form.mobile)

        UserProfileUpdater.new(form).send_notifications
      end
    end
  end

  describe '#attribute_already_taken?' do
    context 'when there are no existing attribute errors' do
      it 'returns false' do
        allow(form).to receive(:errors).and_return({})

        expect(UserProfileUpdater.new(form).attribute_already_taken?).to be_falsey
      end
    end

    context 'when there are existing mobile errors' do
      it 'returns true' do
        allow(form).to receive(:errors).
          and_return(mobile: [t('errors.messages.taken')])

        expect(UserProfileUpdater.new(form).attribute_already_taken?).to be_truthy
      end
    end

    context 'when there are existing email errors' do
      it 'returns true' do
        allow(form).to receive(:errors).
          and_return(email: [t('errors.messages.taken')])

        expect(UserProfileUpdater.new(form).attribute_already_taken?).to be_truthy
      end
    end
  end

  describe '#attribute_already_taken_and_no_other_errors?' do
    context 'when no attributes are already taken' do
      it 'returns false' do
        allow(form).to receive(:errors).and_return({})

        expect(UserProfileUpdater.new(form).
          attribute_already_taken_and_no_other_errors?).to be_falsey
      end
    end

    context 'when attributes are already taken and other errors are present' do
      it 'returns false' do
        allow(form).to receive(:errors).
          and_return(mobile: [t('errors.messages.taken')],
                     current_password: ["can't be blank"])

        expect(UserProfileUpdater.new(form).
          attribute_already_taken_and_no_other_errors?).to be_falsey
      end
    end

    context 'when attributes are already taken and no other errors are present' do
      it 'returns true' do
        allow(form).to receive(:errors).
          and_return(mobile: [t('errors.messages.taken')])

        expect(UserProfileUpdater.new(form).
          attribute_already_taken_and_no_other_errors?).to be_truthy
      end
    end
  end

  describe '#delete_already_taken_errors' do
    context 'when no attributes are already taken' do
      it 'does not delete errors' do
        form.mobile = user.mobile
        form.valid?

        UserProfileUpdater.new(form).delete_already_taken_errors

        expect(form.errors.full_messages).to eq ["Current password can't be blank"]
      end
    end

    context 'when attributes are already taken' do
      it 'deletes errors for attributes that are already taken' do
        second_user = create(:user, :signed_up, email: 'new@email.com', mobile: '+1 (202) 555-1213')
        form.email = second_user.email
        form.mobile = second_user.mobile
        form.valid?

        UserProfileUpdater.new(form).delete_already_taken_errors

        expect(form.errors.full_messages).to eq ["Current password can't be blank"]
      end
    end
  end
end
