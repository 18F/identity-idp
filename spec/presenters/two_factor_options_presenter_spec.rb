require 'rails_helper'

describe TwoFactorOptionsPresenter do
  include Rails.application.routes.url_helpers

  let(:user) { build(:user) }
  let(:user_agent) do
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 \
(KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36'
  end
  let(:presenter) do
    described_class.new(user, nil, user_agent)
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
        TwoFactorAuthentication::AuthAppSelectionPresenter,
        TwoFactorAuthentication::WebauthnSelectionPresenter,
        TwoFactorAuthentication::PhoneSelectionPresenter,
        TwoFactorAuthentication::PivCacSelectionPresenter,
        TwoFactorAuthentication::BackupCodeSelectionPresenter,
      ]
    end

    context 'when hide_phone_mfa_signup is enabled' do
      before do
        allow(FeatureManagement).to receive(:hide_phone_mfa_signup?).and_return(true)
      end

      it 'supplies all the options except phone' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
        ]
      end
    end

    context 'with a user with a phone configured' do
      let(:user) { build(:user, :with_phone) }

      it 'supplies all the options with second phone options' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::SecondPhoneSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
        ]
      end
    end

    context 'with a user with totp configured' do
      let(:user) { build(:user, :with_authentication_app) }

      it 'supplies all the options' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PhoneSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
        ]
      end
    end

    context 'with a user with webauthn configured' do
      let(:user) { build(:user, :with_webauthn) }

      it 'supplies all the options' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PhoneSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
          TwoFactorAuthentication::BackupCodeSelectionPresenter,
        ]
      end
    end

    context 'with a user with backup_code configured' do
      let(:user) { build(:user, :with_backup_code) }

      it 'supplies all the options' do
        expect(presenter.options.map(&:class)).to eq [
          TwoFactorAuthentication::AuthAppSelectionPresenter,
          TwoFactorAuthentication::WebauthnSelectionPresenter,
          TwoFactorAuthentication::PhoneSelectionPresenter,
          TwoFactorAuthentication::PivCacSelectionPresenter,
        ]
      end
    end
  end
end
