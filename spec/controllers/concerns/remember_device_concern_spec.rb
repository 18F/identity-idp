require 'rails_helper'

RSpec.describe RememberDeviceConcern do
  let(:sp) { build(:service_provider) }
  let(:raw_session) { { vtr: ['C1'] } }

  let(:test_class) do
    Class.new(self.class) do
      include(RememberDeviceConcern)

      def current_sp
        sp
      end

      def decorated_sp_session
        ServiceProviderSession.new(
          sp: sp,
          view_context: {},
          sp_session: raw_session,
          service_provider_request: {},
        )
      end
    end
  end

  subject(:test_instance) { test_class.new }

  describe '#mfa_expiration_interval' do
    let(:expected_aal_1_expiration) { 720.hours }
    let(:expected_aal_2_expiration) { 0.hours }

    context 'with no sp' do
      let(:sp) { nil }

      it { expect(test_instance.mfa_expiration_interval).to eq(expected_aal_1_expiration) }
    end

    context 'with an AAL2 sp' do
      let(:sp) { build(:service_provider, default_aal: 2) }

      it { expect(test_instance.mfa_expiration_interval).to eq(expected_aal_2_expiration) }
    end

    context 'with an IAL2 sp' do
      let(:sp) { build(:service_provider, ial: 2) }

      it { expect(test_instance.mfa_expiration_interval).to eq(expected_aal_2_expiration) }
    end

    context 'with an sp that is not AAL2 or IAL2 and AAL1 requested' do
      let(:sp) { build(:service_provider) }

      context 'with vtr' do
        it { expect(test_instance.mfa_expiration_interval).to eq(30.days) }
      end

      context 'with legacy acr' do
        let(:raw_session) { { acr_values: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF } }

        it { expect(test_instance.mfa_expiration_interval).to eq(30.days) }
      end
    end

    context 'with an sp that is not AAL2 or IAL2 and AAL2 requested' do
      let(:raw_session) { { acr_values: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF } }

      it { expect(test_instance.mfa_expiration_interval).to eq(expected_aal_2_expiration) }
    end
  end
end
