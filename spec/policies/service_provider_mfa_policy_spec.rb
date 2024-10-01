require 'rails_helper'

RSpec.describe ServiceProviderMfaPolicy do
  let(:user) { create(:user) }
  let(:auth_method) { TwoFactorAuthenticatable::AuthMethod::SMS }
  let(:aal2) { false }
  let(:hspd12) { false }
  let(:phishing_resistant) { false }
  let(:resolved_authn_context_result) do
    Vot::Parser::Result.new(
      component_values: [],
      component_separator: ' ',
      aal2?: aal2,
      hspd12?: hspd12,
      phishing_resistant?: phishing_resistant,
      identity_proofing?: false,
      facial_match?: false,
      two_pieces_of_fair_evidence?: false,
      ialmax?: false,
      enhanced_ipp?: false,
    )
  end
  let(:auth_methods_session) { AuthMethodsSession.new(user_session: {}) }

  subject(:policy) do
    described_class.new(
      user: user,
      auth_methods_session: auth_methods_session,
      resolved_authn_context_result: resolved_authn_context_result,
    )
  end

  before do
    auth_methods_session.authenticate!(auth_method) if auth_method
  end

  describe '#phishing_resistant_required?' do
    context 'phishing-resistant requested' do
      let(:aal2) { true }
      let(:phishing_resistant) { true }

      it { expect(policy.phishing_resistant_required?).to eq(true) }
    end

    context 'phishing-resistant not requested' do
      let(:phishing_resistant) { false }

      it { expect(policy.phishing_resistant_required?).to eq(false) }
    end
  end

  describe '#user_needs_sp_auth_method_verification?' do
    context 'phishing-resistant required' do
      let(:aal2) { true }
      let(:phishing_resistant) { true }

      context 'the user needs to setup a phishing-resistant method' do
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

      context 'the user did not use a phishing-resistant method' do
        let(:auth_method) { TwoFactorAuthenticatable::AuthMethod::SMS }

        before do
          setup_user_phone
          setup_user_webauthn_token
        end

        it { expect(policy.user_needs_sp_auth_method_verification?).to eq(true) }
      end
    end

    context 'piv/cac required' do
      let(:hspd12) { true }

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

      context 'the user did not use a PIV' do
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
    context 'phishing-resistant required' do
      let(:phishing_resistant) { true }

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
      let(:hspd12) { true }

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
