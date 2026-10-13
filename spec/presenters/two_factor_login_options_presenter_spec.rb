require 'rails_helper'

RSpec.describe TwoFactorLoginOptionsPresenter do
  include AccountResetHelper
  include ActionView::Helpers::OutputSafetyHelper
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::DateHelper
  include Rails.application.routes.url_helpers

  let(:user) { User.new }
  let(:view) { ActionController::Base.new.view_context }
  let(:phishing_resistant_required) { false }
  let(:piv_cac_required) { false }
  let(:reauthentication_context) { false }
  let(:service_provider) { nil }
  let(:add_piv_cac_after_2fa) { false }
  let(:account_recovery_bucket) { nil }

  subject(:presenter) do
    TwoFactorLoginOptionsPresenter.new(
      user:,
      view:,
      reauthentication_context:,
      service_provider:,
      phishing_resistant_required:,
      piv_cac_required:,
      add_piv_cac_after_2fa:,
      account_recovery_bucket:,
    )
  end

  it 'supplies a title' do
    expect(presenter.title).to eq \
      t('two_factor_authentication.login_options_title')
  end

  describe '#heading' do
    subject { presenter.heading }

    context 'default user session context' do
      it { should eq t('two_factor_authentication.login_options_title') }
    end

    context 'reauthentication user session context' do
      let(:reauthentication_context) { true }

      it { should eq t('two_factor_authentication.login_options_reauthentication_title') }
    end
  end

  describe '#info' do
    subject { presenter.info }

    context 'default user session context' do
      it { should eq t('two_factor_authentication.login_intro') }
    end

    context 'add piv cac after 2fa' do
      let(:add_piv_cac_after_2fa) { true }

      it { should eq t('two_factor_authentication.login_intro') }
    end

    context 'reauthentication user session context' do
      let(:reauthentication_context) { true }

      it { should eq t('two_factor_authentication.login_intro_reauthentication') }
    end
  end

  it 'supplies a cancel link when the token is valid' do
    allow(presenter).to receive(:account_reset_token).and_return('foo')
    allow(presenter).to receive(:account_reset_token_valid?).and_return(true)
    allow(IdentityConfig.store).to receive(:account_reset_wait_period_days).and_return(1)

    expect(presenter.account_reset_or_cancel_link).to eq(
      t('two_factor_authentication.account_reset.pending', interval: '24 hours') + ' ' +
        view.link_to(
          t('two_factor_authentication.account_reset.cancel_link'),
          account_reset_cancel_url(token: 'foo'),
        ),
    )
  end

  it 'supplies a reset link when the token is not valid' do
    allow_any_instance_of(TwoFactorLoginOptionsPresenter).to \
      receive(:account_reset_token_valid?).and_return(false)

    expect(presenter.account_reset_or_cancel_link).to eq \
      t(
        'two_factor_authentication.account_reset.text_html',
        link_html: view.link_to(
          t('two_factor_authentication.account_reset.link'),
          account_reset_recovery_options_path(locale: LinkLocaleResolver.locale),
        ),
      )
  end

  describe 'account recovery entry point' do
    let(:user) { create(:user, :fully_registered) }

    before do
      allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    end

    context 'when the user is in the treatment bucket and eligible' do
      let(:account_recovery_bucket) { :account_preserving }

      it 'reports the user as eligible' do
        expect(presenter.account_recovery_eligible?).to eq(true)
      end

      it 'supplies a recover-your-account link' do
        expect(presenter.account_recovery_link).to eq \
          t(
            'two_factor_authentication.account_recovery.recover_text_html',
            link_html: view.link_to(
              t('two_factor_authentication.account_recovery.recover_link'),
              account_recovery_start_path(locale: LinkLocaleResolver.locale),
            ),
          )
      end

      it 'supplies a delete-your-account fallback link to the legacy flow' do
        expect(presenter.account_recovery_delete_link).to eq \
          t(
            'two_factor_authentication.account_recovery.delete_text_html',
            link_html: view.link_to(
              t('two_factor_authentication.account_recovery.delete_link'),
              account_reset_recovery_options_path(locale: LinkLocaleResolver.locale),
            ),
          )
      end

      context 'when the user already has a pending recovery request' do
        before { create(:account_recovery_request, :waiting, user: user) }

        it 'reports the user as ineligible' do
          expect(presenter.account_recovery_eligible?).to eq(false)
        end
      end

      context 'when the user is identity proofed' do
        let(:user) { create(:user, :proofed) }

        it 'reports the user as ineligible' do
          expect(presenter.account_recovery_eligible?).to eq(false)
        end
      end
    end

    context 'when the user is in the control bucket' do
      let(:account_recovery_bucket) { :legacy }

      it 'reports the user as ineligible' do
        expect(presenter.account_recovery_eligible?).to eq(false)
      end
    end

    context 'when the feature is disabled' do
      let(:account_recovery_bucket) { :account_preserving }

      before do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
      end

      it 'reports the user as ineligible' do
        expect(presenter.account_recovery_eligible?).to eq(false)
      end
    end

    context 'when no bucket was assigned' do
      it 'reports the user as ineligible' do
        expect(presenter.account_recovery_eligible?).to eq(false)
      end
    end
  end

  describe '#options' do
    let(:user) do
      create(
        :user,
        :fully_registered,
        :with_webauthn,
        :with_webauthn_platform,
        :with_phone,
        :with_piv_or_cac,
        :with_personal_key,
        :with_backup_code,
        :with_authentication_app,
      )
    end

    subject(:options) { presenter.options }
    let(:options_classes) { options.map(&:class) }

    it 'returns classes for mfas associated with account' do
      expect(options_classes).to eq(
        [
          TwoFactorAuthentication::SignInPhoneSelectionPresenter,
          TwoFactorAuthentication::SignInPhoneSelectionPresenter,
          TwoFactorAuthentication::SignInWebauthnSelectionPresenter,
          TwoFactorAuthentication::SignInBackupCodeSelectionPresenter,
          TwoFactorAuthentication::SignInPivCacSelectionPresenter,
          TwoFactorAuthentication::SignInAuthAppSelectionPresenter,
          TwoFactorAuthentication::SignInPersonalKeySelectionPresenter,
        ],
      )
    end

    it 'has only one webauthn selection presenter' do
      webauthn_selection_presenter_count = options_classes.count do |klass|
        klass == TwoFactorAuthentication::SignInWebauthnSelectionPresenter
      end

      expect(webauthn_selection_presenter_count).to eq 1
    end

    context 'piv cac required' do
      let(:piv_cac_required) { true }

      it 'filters to piv method' do
        expect(options_classes).to eq([TwoFactorAuthentication::SignInPivCacSelectionPresenter])
      end

      context 'in reauthentication context' do
        let(:reauthentication_context) { true }

        it 'returns all mfas associated with account' do
          expect(options_classes).to eq(
            [
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInWebauthnSelectionPresenter,
              TwoFactorAuthentication::SignInBackupCodeSelectionPresenter,
              TwoFactorAuthentication::SignInPivCacSelectionPresenter,
              TwoFactorAuthentication::SignInAuthAppSelectionPresenter,
              TwoFactorAuthentication::SignInPersonalKeySelectionPresenter,
            ],
          )
        end
      end

      context 'with no piv cac mfa yet' do
        let(:user) do
          create(
            :user,
            :fully_registered,
            :with_webauthn,
            :with_webauthn_platform,
            :with_phone,
            :with_personal_key,
            :with_backup_code,
            :with_authentication_app,
          )
        end

        it 'returns all mfas associated with account' do
          expect(options_classes).to eq(
            [
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInWebauthnSelectionPresenter,
              TwoFactorAuthentication::SignInBackupCodeSelectionPresenter,
              TwoFactorAuthentication::SignInAuthAppSelectionPresenter,
              TwoFactorAuthentication::SignInPersonalKeySelectionPresenter,
            ],
          )
        end
      end

      context 'add piv cac after 2fa' do
        let(:add_piv_cac_after_2fa) { true }

        it 'returns all mfas associated with account' do
          expect(options_classes).to eq(
            [
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInWebauthnSelectionPresenter,
              TwoFactorAuthentication::SignInBackupCodeSelectionPresenter,
              TwoFactorAuthentication::SignInPivCacSelectionPresenter,
              TwoFactorAuthentication::SignInAuthAppSelectionPresenter,
              TwoFactorAuthentication::SignInPersonalKeySelectionPresenter,
            ],
          )
        end
      end
    end

    context 'phishing resistant required' do
      let(:phishing_resistant_required) { true }

      it 'filters to phishing resistant methods' do
        expect(options_classes).to eq(
          [
            TwoFactorAuthentication::SignInWebauthnSelectionPresenter,
            TwoFactorAuthentication::SignInPivCacSelectionPresenter,
          ],
        )
      end

      context 'in reauthentication context' do
        let(:reauthentication_context) { true }

        it 'returns all mfas associated with account' do
          expect(options_classes).to eq(
            [
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInWebauthnSelectionPresenter,
              TwoFactorAuthentication::SignInBackupCodeSelectionPresenter,
              TwoFactorAuthentication::SignInPivCacSelectionPresenter,
              TwoFactorAuthentication::SignInAuthAppSelectionPresenter,
              TwoFactorAuthentication::SignInPersonalKeySelectionPresenter,
            ],
          )
        end
      end

      context 'with no phishing resistant mfa' do
        let(:user) do
          create(
            :user,
            :fully_registered,
            :with_phone,
            :with_personal_key,
            :with_backup_code,
            :with_authentication_app,
          )
        end

        it 'returns all mfas associated with account' do
          expect(options_classes).to eq(
            [
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInBackupCodeSelectionPresenter,
              TwoFactorAuthentication::SignInAuthAppSelectionPresenter,
              TwoFactorAuthentication::SignInPersonalKeySelectionPresenter,
            ],
          )
        end
      end

      context 'add piv cac after 2fa' do
        let(:add_piv_cac_after_2fa) { true }

        it 'returns all mfas associated with account' do
          expect(options_classes).to eq(
            [
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInPhoneSelectionPresenter,
              TwoFactorAuthentication::SignInWebauthnSelectionPresenter,
              TwoFactorAuthentication::SignInBackupCodeSelectionPresenter,
              TwoFactorAuthentication::SignInPivCacSelectionPresenter,
              TwoFactorAuthentication::SignInAuthAppSelectionPresenter,
              TwoFactorAuthentication::SignInPersonalKeySelectionPresenter,
            ],
          )
        end
      end
    end

    context 'deprecating personal keys' do
      it 'does not show the personal key option when set to false' do
        allow(IdentityConfig.store).to receive(:personal_key_as_mfa_active).and_return(false)
        expect(options_classes).to eq(
          [
            TwoFactorAuthentication::SignInPhoneSelectionPresenter,
            TwoFactorAuthentication::SignInPhoneSelectionPresenter,
            TwoFactorAuthentication::SignInWebauthnSelectionPresenter,
            TwoFactorAuthentication::SignInBackupCodeSelectionPresenter,
            TwoFactorAuthentication::SignInPivCacSelectionPresenter,
            TwoFactorAuthentication::SignInAuthAppSelectionPresenter,
          ],
        )
      end
    end
  end

  describe '#restricted_options_warning_text' do
    subject(:restricted_options_warning_text) { presenter.restricted_options_warning_text }

    it { should be_nil }

    context 'phishing resistant required' do
      let(:user) do
        create(
          :user,
          :fully_registered,
          :with_webauthn,
          :with_webauthn_platform,
          :with_piv_or_cac,
        )
      end

      let(:phishing_resistant_required) { true }

      it 'returns phishing resistant required warning text for app' do
        expect(restricted_options_warning_text).to eq(
          t('two_factor_authentication.aal2_request.phishing_resistant_html', sp_name: APP_NAME),
        )
      end

      context 'with sp' do
        let(:service_provider) { build(:service_provider) }

        it 'returns phishing resistant required warning text for service provider' do
          expect(restricted_options_warning_text).to eq(
            t(
              'two_factor_authentication.aal2_request.phishing_resistant_html',
              sp_name: service_provider.friendly_name,
            ),
          )
        end
      end

      context 'in reauthentication context' do
        let(:reauthentication_context) { true }

        it { should be_nil }
      end

      context 'add piv cac after 2fa' do
        let(:add_piv_cac_after_2fa) { true }

        it { should be_nil }
      end
    end

    context 'piv cac required' do
      let(:piv_cac_required) { true }
      let(:user) do
        create(
          :user,
          :fully_registered,
          :with_webauthn,
          :with_webauthn_platform,
          :with_piv_or_cac,
        )
      end

      it 'returns piv cac required warning text for app' do
        expect(restricted_options_warning_text).to eq(
          t('two_factor_authentication.aal2_request.piv_cac_only_html', sp_name: APP_NAME),
        )
      end

      context 'with sp' do
        let(:service_provider) { build(:service_provider) }

        it 'returns piv cac required warning text for service provider' do
          expect(restricted_options_warning_text).to eq(
            t(
              'two_factor_authentication.aal2_request.piv_cac_only_html',
              sp_name: service_provider.friendly_name,
            ),
          )
        end
      end

      context 'in reauthentication context' do
        let(:reauthentication_context) { true }

        it { should be_nil }
      end

      context 'add piv cac after 2fa' do
        let(:add_piv_cac_after_2fa) { true }

        it { should be_nil }
      end
    end
  end

  describe '#cancel_link' do
    subject(:cancel_link) { presenter.cancel_link }

    context 'default user session context' do
      let(:reauthentication_context) { false }

      it { should eq sign_out_path }
    end

    context 'reauthentication user session context' do
      let(:reauthentication_context) { true }

      it { should eq account_path }
    end
  end

  describe '#first_enabled_option_index' do
    subject(:index) { presenter.first_enabled_option_index }

    it 'returns first index' do
      expect(index).to eq(0)
    end

    context 'enabled options' do
      before do
        create(:phone_configuration, user: user, phone: '(202) 555-1111')
      end

      it 'returns first enabled index' do
        expect(index).to eq(0)
      end
    end

    context 'disabled options' do
      before do
        create(:phone_configuration, user: user, phone: '(202) 555-1111')
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).and_return(false)
        allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
      end

      it 'returns first enabled index' do
        expect(index).to eq(1)
      end
    end
  end
end
