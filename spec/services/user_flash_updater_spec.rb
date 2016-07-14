require 'rails_helper'

describe UserFlashUpdater do
  let(:user) { create(:user, :signed_up) }
  let(:second_user) { create(:user, :signed_up, mobile: '+1 (202) 555-1213') }
  let(:form) { UpdateUserProfileForm.new(user) }

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

    context 'when mobile is updated' do
      it 'returns a mobile confirmation notice' do
        form.submit(mobile: second_user.mobile)

        flash = {}
        updated_flash = { notice: t('devise.registrations.mobile_update_needs_confirmation') }

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

    context 'when both email and mobile are updated to ones that have already been taken' do
      it 'returns both an email and mobile confirmation notice' do
        user.update(mobile: second_user.mobile, email: second_user.email)
        allow(form).to receive(:mobile_changed?).and_return(true)

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_and_mobile_need_confirmation') }

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

    context 'when mobile is updated' do
      it 'returns a mobile confirmation notice' do
        user.update(mobile: '555-333-1212')
        allow(form).to receive(:mobile_changed?).and_return(true)

        flash = {}
        updated_flash = { notice: t('devise.registrations.mobile_update_needs_confirmation') }

        UserFlashUpdater.new(form, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when both email and mobile are updated' do
      it 'returns both an email and mobile confirmation notice' do
        user.update(email: 'foo@example.com')
        allow(form).to receive(:mobile_changed?).and_return(true)

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_and_mobile_need_confirmation') }

        UserFlashUpdater.new(form, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end
  end
end
