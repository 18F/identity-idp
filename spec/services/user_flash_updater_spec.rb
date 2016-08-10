require 'rails_helper'

describe UserFlashUpdater do
  let(:user) { create(:user, :signed_up) }
  let(:second_user) { create(:user, :signed_up, phone: '+1 (202) 555-1213') }
  let(:form) { UpdateUserPhoneForm.new(user) }

  describe '#set_flash_message' do
    context 'when there are no attribute changes that need confirmation' do
      it 'returns a plain updated notice' do
        user.update(sign_in_count: 2)

        flash = {}
        updated_flash = { notice: t('devise.registrations.updated') }

        UserFlashUpdater.new(form, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when phone is updated' do
      it 'returns a phone confirmation notice' do
        form.submit(phone: second_user.phone)

        flash = {}
        updated_flash = { notice: t('devise.registrations.phone_update_needs_confirmation') }

        UserFlashUpdater.new(form, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when email is updated to one that has already been taken' do
      it 'returns an email confirmation notice' do
        user.update(email: second_user.email)

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_update_needs_confirmation') }

        UserFlashUpdater.new(form, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when both email and phone are updated to ones that have already been taken' do
      it 'returns both an email and phone confirmation notice' do
        user.update(phone: second_user.phone, email: second_user.email)
        allow(form).to receive(:phone_changed?).and_return(true)

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_and_phone_need_confirmation') }

        UserFlashUpdater.new(form, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when email is updated' do
      it 'returns an email confirmation notice' do
        user.update(email: 'foo@example.com')

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_update_needs_confirmation') }

        UserFlashUpdater.new(form, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when phone is updated' do
      it 'returns a phone confirmation notice' do
        user.update(phone: '555-333-1212')
        allow(form).to receive(:phone_changed?).and_return(true)

        flash = {}
        updated_flash = { notice: t('devise.registrations.phone_update_needs_confirmation') }

        UserFlashUpdater.new(form, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when both email and phone are updated' do
      it 'returns both an email and phone confirmation notice' do
        user.update(email: 'foo@example.com')
        allow(form).to receive(:phone_changed?).and_return(true)

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_and_phone_need_confirmation') }

        UserFlashUpdater.new(form, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end
  end
end
