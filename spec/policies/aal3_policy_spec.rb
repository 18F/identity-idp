require 'rails_helper'

describe AAL3Policy do
  let(:user) { create(:user) }
  let(:service_provider) { create(:service_provider, aal: 1) }
  let(:auth_method) { 'phone' }
  let(:aal_level_requested) { 1 }

  describe '#aal3_required?' do
    it 'is false if the SP did not request and does not require AAL3' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: auth_method,
        aal_level_requested: aal_level_requested,
      )

      expect(aal3_policy.aal3_required?).to eq(false)
    end

    it 'is true if the SP requested AAL3' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: auth_method,
        aal_level_requested: 3,
      )

      expect(aal3_policy.aal3_required?).to eq(true)
    end

    it 'is true if the SP is configured for AAL3 only' do
      service_provider.update!(aal: 3)
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: auth_method,
        aal_level_requested: aal_level_requested,
      )

      expect(aal3_policy.aal3_required?).to eq(true)
    end

    it 'is false if there is no SP' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: nil,
        auth_method: auth_method,
        aal_level_requested: nil,
      )

      expect(aal3_policy.aal3_required?).to eq(false)
    end
  end

  describe '#aal3_used?' do
    it 'returns true if the user used PIV/CAC for MFA' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: 'piv_cac',
        aal_level_requested: aal_level_requested,
      )

      expect(aal3_policy.aal3_used?).to eq(true)
    end

    it 'returns true if the user used webauthn for MFA' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: 'webauthn',
        aal_level_requested: aal_level_requested,
      )

      expect(aal3_policy.aal3_used?).to eq(true)
    end

    it 'returns false if the user has not used an AAL3 method for MFA' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: 'phone',
        aal_level_requested: aal_level_requested,
      )

      expect(aal3_policy.aal3_used?).to eq(false)
    end
  end

  describe '#aal3_required_but_not_used?' do
    it 'returns false if AAL3 is not required' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: auth_method,
        aal_level_requested: aal_level_requested,
      )

      expect(aal3_policy.aal3_required_but_not_used?).to eq(false)
    end

    it 'returns true if AAL3 is required and was not used to sign in' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: auth_method,
        aal_level_requested: 3,
      )

      expect(aal3_policy.aal3_required_but_not_used?).to eq(true)
    end

    it 'returns false if AAL3 is required and was used to sign in' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: 'webauthn',
        aal_level_requested: 3,
      )

      expect(aal3_policy.aal3_required_but_not_used?).to eq(false)
    end
  end

  describe '#aal3_configured_but_not_used?' do
    it 'returns false if AAL3 is configured and not required and not used' do
      configure_aal3_for_user(user)
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: auth_method,
        aal_level_requested: aal_level_requested,
      )

      expect(aal3_policy.aal3_configured_but_not_used?).to eq(false)
    end

    it 'returns false if AAL3 is not configured' do
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: auth_method,
        aal_level_requested: 3,
      )

      expect(aal3_policy.aal3_configured_but_not_used?).to eq(false)
    end

    it 'returns true if AAL3 is configured and was not used to sign in' do
      configure_aal3_for_user(user)
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: auth_method,
        aal_level_requested: 3,
      )

      expect(aal3_policy.aal3_configured_but_not_used?).to eq(true)
    end

    it 'returns false if AAL3 is configured and was used to sign in' do
      configure_aal3_for_user(user)
      aal3_policy = AAL3Policy.new(
        user: user,
        service_provider: service_provider,
        auth_method: 'webauthn',
        aal_level_requested: 3,
      )

      expect(aal3_policy.aal3_configured_but_not_used?).to eq(false)
    end
  end

  describe '#piv_cac_only_required?' do
    context 'when allow_piv_cac_required is true' do
      before(:each) do
        allow(Figaro.env).to receive(:allow_piv_cac_required).and_return('true')
      end

      it 'returns false if the session is nil' do
        session = nil

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if the session has no sp session' do
        session = {}

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if the session has an empty sp session' do
        session = { sp: {} }

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if Hsdpd12 PIV/CAC is not requested' do
        session = { sp: { hspd12_piv_cac_requested: false } }

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns true if Hsdpd12 PIV/CAC is requested' do
        session = { sp: { hspd12_piv_cac_requested: true } }

        expect_piv_cac_required_to(be_truthy, session)
      end
    end

    context 'when allow_piv_cac_required is false' do
      before(:each) do
        allow(Figaro.env).to receive(:allow_piv_cac_required).and_return('false')
      end

      it 'returns false if the session is nil' do
        session = nil

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if the session has no sp session' do
        session = {}

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if the session has an empty sp session' do
        session = { sp: {} }

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if Hsdpd12 PIV/CAC is not requested' do
        session = { sp: { hspd12_piv_cac_requested: false } }

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if Hsdpd12 PIV/CAC is requested' do
        session = { sp: { hspd12_piv_cac_requested: true } }

        expect_piv_cac_required_to(be_falsey, session)
      end
    end
  end

  describe '#piv_cac_only_setup_required?' do
    context 'when the user already has a piv/cac configured' do
      before(:each) do
        allow_any_instance_of(TwoFactorAuthentication::PivCacPolicy).to receive(:enabled?).
          and_return(true)
      end

      it 'returns false if piv/cac is required' do
        allow_any_instance_of(AAL3Policy).to receive(:piv_cac_only_required?).and_return(true)

        expect_piv_cac_setup_required_to be_falsey
      end

      it 'returns false if piv/cac is not required' do
        allow_any_instance_of(AAL3Policy).to receive(:piv_cac_only_required?).and_return(false)

        expect_piv_cac_setup_required_to be_falsey
      end
    end

    context 'when the user has no piv/cac configured' do
      before(:each) do
        allow_any_instance_of(TwoFactorAuthentication::PivCacPolicy).to receive(:enabled?).
          and_return(false)
      end

      it 'returns true if piv/cac is required' do
        allow_any_instance_of(AAL3Policy).to receive(:piv_cac_only_required?).and_return(true)

        expect_piv_cac_setup_required_to be_truthy
      end

      it 'returns false if piv/cac is not required' do
        allow_any_instance_of(AAL3Policy).to receive(:piv_cac_only_required?).and_return(false)

        expect_piv_cac_setup_required_to be_falsey
      end
    end
  end

  def expect_piv_cac_required_to(value, session)
    expect(AAL3Policy.new(user: user, session: session).piv_cac_only_required?).to(value)
  end

  def expect_piv_cac_setup_required_to(value)
    expect(AAL3Policy.new(user: user, session: :foo).piv_cac_only_setup_required?).to(value)
  end

  def configure_aal3_for_user(user)
    user.webauthn_configurations << create(:webauthn_configuration)
    user.save!
  end
end
