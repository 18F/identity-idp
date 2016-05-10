require 'rails_helper'

describe UserFlashUpdater do
  let(:user) { create(:user, :signed_up) }
  let(:second_user) { create(:user, :signed_up, mobile: '+1 (202) 555-1213') }

  describe '#set_flash_message' do
    context 'when there are no attribute changes that need confirmation' do
      it 'returns a plain updated notice' do
        user.update(ial_token: 'foo')

        flash = {}
        updated_flash = { notice: t('devise.registrations.updated') }

        UserFlashUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when mobile is updated to one that has already been taken' do
      it 'returns a mobile confirmation notice' do
        user.update(mobile: second_user.mobile)

        flash = {}
        updated_flash = { notice: t('devise.registrations.mobile_update_needs_confirmation') }

        UserFlashUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when email is updated to one that has already been taken' do
      it 'returns an email confirmation notice' do
        user.update(email: second_user.email)

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_update_needs_confirmation') }

        UserFlashUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when both email and mobile are updated to ones that have already been taken' do
      it 'returns both an email and mobile confirmation notice' do
        user.update(mobile: second_user.mobile, email: second_user.email)

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_and_mobile_need_confirmation') }

        UserFlashUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when email is updated' do
      it 'returns an email confirmation notice' do
        user.update(email: 'foo@example.com')

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_update_needs_confirmation') }

        UserFlashUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when mobile is updated' do
      it 'returns a mobile confirmation notice' do
        user.update(mobile: '555-333-1212')

        flash = {}
        updated_flash = { notice: t('devise.registrations.mobile_update_needs_confirmation') }

        UserFlashUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end

    context 'when both email and mobile are updated' do
      it 'returns both an email and mobile confirmation notice' do
        user.update(mobile: '333-444-1212', email: 'foo@example.com')

        flash = {}
        updated_flash = { notice: t('devise.registrations.email_and_mobile_need_confirmation') }

        UserFlashUpdater.new(user, flash).set_flash_message

        expect(flash).to eq updated_flash
      end
    end
  end

  describe '#needs_to_confirm_mobile_change?' do
    context 'when user is not pending_mobile_reconfirmation' do
      it 'returns false' do
        allow(user).to receive(:pending_mobile_reconfirmation?).and_return(false)

        expect(UserFlashUpdater.new(user, {}).needs_to_confirm_mobile_change?).to be false
      end
    end

    context 'when user is pending_mobile_reconfirmation' do
      it 'returns true' do
        allow(user).to receive(:pending_mobile_reconfirmation?).and_return(true)

        expect(UserFlashUpdater.new(user, {}).needs_to_confirm_mobile_change?).to be true
      end
    end

    context 'when user has changed their mobile' do
      it 'returns true' do
        allow(user).to receive(:mobile_changed?).and_return(true)

        expect(UserFlashUpdater.new(user, {}).needs_to_confirm_mobile_change?).to be true
      end
    end

    context 'when user has not changed their mobile' do
      it 'returns false' do
        allow(user).to receive(:mobile_changed?).and_return(false)

        expect(UserFlashUpdater.new(user, {}).needs_to_confirm_mobile_change?).to be false
      end
    end
  end
end
