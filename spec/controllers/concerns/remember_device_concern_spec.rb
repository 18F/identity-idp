require 'rails_helper'

RSpec.describe RememberDeviceConcern do
  let(:sp) { build(:service_provider) }
  let(:raw_session) { {} }
  let(:request) do
    double(
      'request',
      session: raw_session,
      parameters: {},
      filtered_parameters: {},
    )
  end

  let(:test_class) do
    Class.new(ApplicationController) do
      include(RememberDeviceConcern)

      attr_reader :raw_session, :request

      def initialize(sp, raw_session, request)
        @sp = sp
        @raw_session = raw_session
        @request = request
      end

      def decorated_sp_session
        ServiceProviderSession.new(
          sp: @sp,
          view_context: {},
          sp_session: @raw_session,
          service_provider_request: {},
        )
      end

      def sp_from_sp_session
        @sp
      end

      def sp_session
        @raw_session
      end
    end
  end

  subject(:test_instance) { test_class.new(sp, raw_session, request) }

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

    context 'with an sp that is not AAL2 or IAL2' do
      let(:sp) { build(:service_provider) }

      context 'and AAL1 requested' do
        context 'with vtr' do
          let(:raw_session) { { vtr: ['C1'] } }

          it { expect(test_instance.mfa_expiration_interval).to eq(30.days) }
        end

        context 'with legacy acr' do
          let(:raw_session) { { acr_values: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF } }

          it { expect(test_instance.mfa_expiration_interval).to eq(30.days) }
        end
      end

      context 'and AAL2 requested' do
        context 'with vtr' do
          let(:raw_session) { { vtr: ['C2'] } }

          it { expect(test_instance.mfa_expiration_interval).to eq(expected_aal_2_expiration) }
        end

        context 'with legacy acr' do
          let(:raw_session) { { acr_values: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF } }

          it { expect(test_instance.mfa_expiration_interval).to eq(expected_aal_2_expiration) }
        end
      end
    end
  end
end
