require 'rails_helper'

describe UserProfileUpdater do
  describe '#send_notifications' do
    context 'when email is already taken' do
      it 'sends an email to the existing user' do
        user = create(:user)
        existing_user = create(:user, email: 'existing@example.com')
        user.update(email: existing_user.email)

        mailer = instance_double(ActionMailer::MessageDelivery)
        expect(UserMailer).to receive(:signup_with_your_email).with(existing_user).
          and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        UserProfileUpdater.new(user).send_notifications
      end
    end

    context 'when mobile is already taken' do
      it 'sends an SMS to the existing user' do
        user = create(:user)
        existing_user = create(:user, mobile: '222-555-1212')
        user.update(mobile: existing_user.mobile)

        expect(SmsSenderExistingMobileJob).to receive(:perform_later).
          with(existing_user)

        UserProfileUpdater.new(user).send_notifications
      end
    end

    context 'when both email and mobile are already taken' do
      it 'sends an email and SMS to the existing user' do
        user = create(:user)
        existing_user = create(:user, email: 'existing@example.com', mobile: '222-555-1212')
        user.update(email: existing_user.email, mobile: existing_user.mobile)

        mailer = instance_double(ActionMailer::MessageDelivery)
        expect(UserMailer).to receive(:signup_with_your_email).with(existing_user).
          and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        expect(SmsSenderExistingMobileJob).to receive(:perform_later).
          with(existing_user)

        UserProfileUpdater.new(user).send_notifications
      end
    end
  end

  describe '#attribute_already_taken?' do
    context 'when there are no existing attribute errors' do
      it 'returns false' do
        user = create(:user)
        user.update(email: 'foo@example.com', mobile: '222-555-1212')

        expect(UserProfileUpdater.new(user).attribute_already_taken?).to be_falsey
      end
    end

    context 'when there are existing mobile errors' do
      it 'returns true' do
        user = create(:user)
        existing_user = create(:user, mobile: '222-555-1212')
        user.update(mobile: existing_user.mobile)

        expect(UserProfileUpdater.new(user).attribute_already_taken?).to be_truthy
      end
    end

    context 'when there are existing email errors' do
      it 'returns true' do
        user = create(:user)
        existing_user = create(:user, email: 'existing@example.com')
        user.update(email: existing_user.email)

        expect(UserProfileUpdater.new(user).attribute_already_taken?).to be_truthy
      end
    end
  end

  describe '#set_flash_message' do
    context 'when there are no attribute changes that need confirmation' do
      it 'returns a plain updated notice' do
        user = create(:user)
        user.update(ial_token: 'foo')

        flash = {}
        updated_flash = { notice: t('devise.registrations.updated') }

        UserProfileUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when there are existing mobile errors' do
      it 'returns a mobile confirmation notice' do
        user = create(:user)
        existing_user = create(:user, mobile: '222-555-1212')
        user.update(mobile: existing_user.mobile)

        flash = {}
        updated_flash = { notice: t('devise.registrations.mobile_update_needs_confirmation') }

        UserProfileUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when there are existing email errors' do
      it 'returns an email confirmation notice' do
        user = create(:user)
        existing_user = create(:user, email: 'existing@example.com')
        user.update(email: existing_user.email)

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_update_needs_confirmation') }

        UserProfileUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when there are existing email and mobile errors' do
      it 'returns both an email and mobile confirmation notice' do
        user = create(:user)
        existing_user = create(:user, mobile: '222-555-1212')
        user.update(mobile: existing_user.mobile, email: existing_user.email)

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_and_mobile_need_confirmation') }

        UserProfileUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when email is updated' do
      it 'returns an email confirmation notice' do
        user = create(:user)
        user.update(email: 'foo@example.com')

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_update_needs_confirmation') }

        UserProfileUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when mobile is updated' do
      it 'returns a mobile confirmation notice' do
        user = create(:user)
        user.update(mobile: '555-333-1212')

        flash = {}
        updated_flash = { notice: t('devise.registrations.mobile_update_needs_confirmation') }

        UserProfileUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when both email and mobile are updated' do
      it 'returns both an email and mobile confirmation notice' do
        user = create(:user)
        user.update(mobile: '333-444-1212', email: 'foo@example.com')

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_and_mobile_need_confirmation') }

        UserProfileUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end
  end
end
