require 'rails_helper'

describe TwoFactorOptionsPresenter do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:presenter) do
    described_class.new(user, nil)
  end

  it 'supplies a title' do
    expect(presenter.title).to eq \
      t('titles.two_factor_setup')
  end

  it 'supplies a heading' do
    expect(presenter.heading).to eq \
      t('two_factor_authentication.two_factor_choice')
  end

  describe '#options' do
    it 'supplies all the options for a user with no mfa configured' do
      expect(presenter.options.map(&:class)).to eq [
        TwoFactorAuthentication::PhoneSelectionPresenter,
        TwoFactorAuthentication::AuthAppSelectionPresenter,
        TwoFactorAuthentication::WebauthnSelectionPresenter,
        TwoFactorAuthentication::PivCacSelectionPresenter,
        TwoFactorAuthentication::BackupCodeSelectionPresenter,
      ]
    end

    context 'with a user with a phone configured' do
      let(:user) { build(:user, :with_phone) }

      it 'supplies all the options with second phone options' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::SecondPhoneSelectionPresenter,
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
        ]
      end
    end

    context 'with a user with totp configured' do
      let(:user) { build(:user, :with_authentication_app) }

      it 'supplies all the options but the auth app' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::PhoneSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
        ]
      end
    end

    context 'with a user with webauthn configured' do
      let(:user) { build(:user, :with_webauthn) }

      it 'supplies all the options' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::PhoneSelectionPresenter,
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
        ]
      end
    end

    context 'with a user with backup_code configured' do
      let(:user) { build(:user, :with_backup_code) }

      it 'supplies all the options' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::PhoneSelectionPresenter,
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
        ]
      end
    end
  end

  describe 'shows correct step indicator' do
    context 'with a user who has not chosen their first option' do
      let(:user) { build(:user) }

      it 'shows user is on step 3 of 4' do
        expect(presenter.step).to eq '3'
      end
    end

    context 'with a user who has chosen their first option' do
      let(:user) { build(:user, :with_webauthn) }

      it 'shows user is on step 4 of 4' do
        expect(presenter.step).to eq '4'
      end
    end
  end
end
