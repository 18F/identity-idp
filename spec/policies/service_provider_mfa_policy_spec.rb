require 'rails_helper'

describe ServiceProviderMfaPolicy do
  let(:user) { create(:user) }
  let(:service_provider) { create(:service_provider) }
  let(:auth_method) { 'phone' }
  let(:aal_level_requested) { 1 }
  let(:piv_cac_requested) { false }
  let(:phishing_resistant_requested) { nil }

  subject(:policy) do
    described_class.new(
      user: user,
      service_provider: service_provider,
      auth_method: auth_method,
      aal_level_requested: aal_level_requested,
      piv_cac_requested: piv_cac_requested,
      phishing_resistant_requested: phishing_resistant_requested,
    )
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

      context 'the user did not use an AAL3 method' do
        let(:auth_method) { 'phone' }

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
        let(:auth_method) { 'phone' }

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
    end
  end

  describe '#auth_method_confirms_to_sp_request?' do
    context 'the user used the required MFA' do
      before do
        setup_user_phone
        setup_user_webauthn_token
      end

      let(:aal_level_requested) { 3 }
      let(:auth_method) { 'webauthn' }

      it { expect(policy.auth_method_confirms_to_sp_request?).to eq(true) }
    end

    context 'the user did not use the required MFA' do
      before do
        setup_user_phone
        setup_user_webauthn_token
      end

      let(:aal_level_requested) { 3 }
      let(:auth_method) { 'phone' }

      it { expect(policy.auth_method_confirms_to_sp_request?).to eq(false) }
    end

    context 'the user has not setup the required MFA' do
      before { setup_user_phone }

      let(:aal_level_requested) { 3 }
      let(:auth_method) { 'phone' }

      it { expect(policy.auth_method_confirms_to_sp_request?).to eq(false) }
    end

    context 'there are no MFA requirements' do
      before { setup_user_phone }

      let(:aal_level_requested) { 1 }
      let(:auth_method) { 'phone' }

      it { expect(policy.auth_method_confirms_to_sp_request?).to eq(true) }
    end
  end

  describe '#allow_user_to_switch_method?' do
    context 'phishing-resistant required' do
      let(:aal_level_requested) { 3 }

      context 'the user has more than one phishing-resistant method' do
        before do
          setup_user_webauthn_token
          setup_user_piv
        end

        it { expect(policy.allow_user_to_switch_method?).to eq(true) }
      end

      context 'the user does not have more than one aal3 method' do
        before do
          setup_user_webauthn_token
        end

        it { expect(policy.allow_user_to_switch_method?).to eq(false) }
      end
    end

    context 'piv/cac required' do
      let(:aal_level_requested) { 3 }
      let(:piv_cac_requested) { true }

      context 'the user has a PIV' do
        before { setup_user_piv }

        it { expect(policy.allow_user_to_switch_method?).to eq(false) }
      end

      context 'the user does not have a PIV' do
        before { setup_user_webauthn_token }

        it { expect(policy.allow_user_to_switch_method?).to eq(false) }
      end

      context 'the user has a PIV and webauthn token' do
        before do
          setup_user_webauthn_token
          setup_user_piv
        end

        it { expect(policy.allow_user_to_switch_method?).to eq(false) }
      end
    end

    context 'there are no MFA reqirements' do
      before { setup_user_phone }

      it { expect(policy.allow_user_to_switch_method?).to eq(true) }
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
