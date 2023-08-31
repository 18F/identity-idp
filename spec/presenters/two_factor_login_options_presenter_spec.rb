require 'rails_helper'

RSpec.describe TwoFactorLoginOptionsPresenter do
  include Rails.application.routes.url_helpers

  let(:user) { User.new }
  let(:view) { ActionController::Base.new.view_context }
  let(:phishing_resistant_required) { false }
  let(:piv_cac_required) { false }
  let(:reauthentication_context) { false }
  let(:service_provider) { nil }

  subject(:presenter) do
    TwoFactorLoginOptionsPresenter.new(
      user: user,
      view: view,
      reauthentication_context: reauthentication_context,
      service_provider: service_provider,
      phishing_resistant_required: phishing_resistant_required,
      piv_cac_required: piv_cac_required,
    )
  end

  it 'supplies a title' do
    expect(presenter.title).to eq \
      t('two_factor_authentication.login_options_title')
  end

  it 'supplies a heading' do
    expect(presenter.heading).to eq \
      t('two_factor_authentication.login_options_title')
  end

  it 'supplies a cancel link when the token is valid' do
    allow_any_instance_of(TwoFactorLoginOptionsPresenter).to \
      receive(:account_reset_token_valid?).and_return(true)

    allow_any_instance_of(TwoFactorLoginOptionsPresenter).to \
      receive(:account_reset_token).and_return('foo')

    expect(presenter.account_reset_or_cancel_link).to eq(
      t('two_factor_authentication.account_reset.pending') + ' ' +
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

  context 'with multiple webauthn configurations' do
    let(:user) { create(:user) }
    before(:each) do
      create_list(:webauthn_configuration, 2, user: user)
      user.webauthn_configurations.reload
    end

    it 'has only one webauthn selection presenter' do
      webauthn_selection_presenters = presenter.options.map(&:class).select do |klass|
        klass == TwoFactorAuthentication::WebauthnSelectionPresenter
      end
      expect(webauthn_selection_presenters.count).to eq 1
    end
  end

  describe '#restricted_options_warning_text' do
    subject(:restricted_options_warning_text) { presenter.restricted_options_warning_text }

    it { should be_nil }

    context 'phishing resistant required' do
      let(:phishing_resistant_required) { true }

      it 'returns phishing resistant required warning text for app' do
        expect(restricted_options_warning_text).to eq(
          t('two_factor_authentication.aal2_request.phishing_resistant_html', sp_name: APP_NAME),
        )
      end

      context 'piv cac required' do
        let(:piv_cac_required) { true }

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
    end

    context 'piv cac required' do
      let(:piv_cac_required) { true }

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
