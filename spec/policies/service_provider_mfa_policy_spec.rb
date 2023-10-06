require 'rails_helper'

RSpec.describe ServiceProviderMfaPolicy do
  let(:user) { create(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:auth_method) { TwoFactorAuthenticatable::AuthMethod::SMS }
  let(:aal_level_requested) { 1 }
  let(:piv_cac_requested) { false }
  let(:phishing_resistant_requested) { nil }
  let(:auth_methods_session) { AuthMethodsSession.new(user_session: {}) }

  subject(:policy) do
    described_class.new(
      user: user,
      service_provider: service_provider,
      auth_methods_session: auth_methods_session,
      aal_level_requested: aal_level_requested,
      piv_cac_requested: piv_cac_requested,
      phishing_resistant_requested: phishing_resistant_requested,
    )
  end

  before do
    auth_methods_session.authenticate!(auth_method) if auth_method
  end

  describe '#phishing_resistant_required?' do
    context 'AAL 3 requested' do
      let(:aal_level_requested) { 3 }
      before { service_provider.default_aal = nil }

      it { expect(policy.phishing_resistant_required?).to eq(true) }
    end

    context 'phishing-resistant requested' do
      let(:phishing_resistant_requested) { true }
      before { service_provider.default_aal = nil }

      it { expect(policy.phishing_resistant_required?).to eq(true) }
    end

    context 'no aal level requested, SP default is aal3' do
      let(:aal_level_requested) { nil }
      before { service_provider.default_aal = 3 }

      it { expect(policy.phishing_resistant_required?).to eq(true) }
    end

    context 'aal2 requested, no default set' do
      let(:aal_level_requested) { 2 }
      before { service_provider.default_aal = nil }

      it { expect(policy.phishing_resistant_required?).to eq(false) }
    end

    context 'aal2 level requested, SP default is aal3' do
      let(:aal_level_requested) { 2 }
      before { service_provider.default_aal = 3 }

      it { expect(policy.phishing_resistant_required?).to eq(false) }
    end
  end

  describe '#user_needs_sp_auth_method_verification?' do
    context 'aal3 required' do
      let(:aal_level_requested) { 3 }

      context 'the user needs to setup an AAL3 method' do
        before { setup_user_phone }

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(false) }
      end

      context 'the user used PIV/CAC' do
        let(:auth_method) { 'piv_cac' }

        before { setup_user_piv }

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(false) }
      end

      context 'the user used webauthn' do
        let(:auth_method) { 'webauthn' }

        before { setup_user_webauthn_token }

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(false) }
      end

      context 'the user uses an eligible method and authenticates with another method afterward' do
        let(:auth_method) { 'webauthn' }

        before do
          setup_user_webauthn_token
          auth_methods_session.authenticate!(TwoFactorAuthenticatable::AuthMethod::SMS)
        end

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(false) }
      end

      context 'the user did not use an AAL3 method' do
        let(:auth_method) { TwoFactorAuthenticatable::AuthMethod::SMS }

        before do
          setup_user_phone
          setup_user_webauthn_token
        end

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(true) }
      end
    end

    context 'piv/cac required' do
      let(:aal_level_requested) { 3 }
      let(:piv_cac_requested) { true }

      context 'the user needs to setup a PIV' do
        before { setup_user_phone }

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(false) }
      end

      context 'the user used PIV/CAC' do
        let(:auth_method) { 'piv_cac' }

        before { setup_user_piv }

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(false) }

        context 'the user authenticates with another method after using PIV/CAC' do
          before do
            auth_methods_session.authenticate!(TwoFactorAuthenticatable::AuthMethod::SMS)
          end

          it { expect(policy.user_needs_sp_auth_method_verification?).to eq(false) }
        end
      end

      context 'the user used webauthn' do
        let(:auth_method) { 'webauthn' }

        before do
          setup_user_webauthn_token
          setup_user_piv
        end

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(true) }
      end

      context 'the user did not use an AAL3 method' do
        let(:auth_method) { TwoFactorAuthenticatable::AuthMethod::SMS }

        before do
          setup_user_phone
          setup_user_piv
        end

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(true) }
      end
    end

    context 'no MFA requirements' do
      before do
        setup_user_phone
      end

      it { expect(policy.user_needs_sp_auth_method_verification?).to eq(false) }

      context 'user has not authenticated' do
        let(:auth_method) { nil }

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(false) }
      end
    end
  end

  describe '#user_needs_sp_auth_method_setup?' do
    context 'aal3 required' do
      let(:aal_level_requested) { 3 }

      context 'the user has PIV/CAC configured' do
        before { setup_user_piv }

        it { expect(policy.user_needs_sp_auth_method_setup?).to eq(false) }
      end

      context 'the user has webauthn configured' do
        before { setup_user_webauthn_token }

        it { expect(policy.user_needs_sp_auth_method_setup?).to eq(false) }
      end

      context 'the user does not have an AAL3 method configured' do
        before { setup_user_phone }

        it { expect(policy.user_needs_sp_auth_method_setup?).to eq(true) }
      end
    end

    context 'piv/cac required' do
      let(:aal_level_requested) { 3 }
      let(:piv_cac_requested) { true }

      context 'the user has PIV/CAC configured' do
        before { setup_user_piv }

        it { expect(policy.user_needs_sp_auth_method_setup?).to eq(false) }
      end

      context 'the user has webauthn configured' do
        before { setup_user_webauthn_token }

        it { expect(policy.user_needs_sp_auth_method_setup?).to eq(true) }
      end

      context 'the user does not have an AAL3 method configured' do
        before { setup_user_phone }

        it { expect(policy.user_needs_sp_auth_method_setup?).to eq(true) }
      end
    end

    context 'no MFA requirements' do
      before { setup_user_phone }

      it { expect(policy.user_needs_sp_auth_method_setup?).to eq(false) }

      context 'user has not authenticated' do
        let(:auth_method) { nil }

        it { expect(policy.user_needs_sp_auth_method_setup?).to eq(false) }
      end
    end
  end

  def setup_user_phone
    user.phone_configurations << build(:phone_configuration)
    user.save!
  end

  def setup_user_piv
    user.piv_cac_configurations.create(x509_dn_uuid: 'helloworld', name: 'My PIV Card')
    user.reload
  end

  def setup_user_webauthn_token
    user.webauthn_configurations << build(:webauthn_configuration)
    user.save!
  end
end
