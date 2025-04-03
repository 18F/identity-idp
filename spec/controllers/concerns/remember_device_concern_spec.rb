require 'rails_helper'

RSpec.describe RememberDeviceConcern do
  let(:sp) { nil }
  let(:raw_session) { {} }
  let(:current_user) { build(:user) }

  subject(:test_controller) do
    test_controller_class =
      Class.new(ApplicationController) do
        include(RememberDeviceConcern)

        attr_reader :sp, :raw_session, :request, :current_user
        alias_method :sp_from_sp_session, :sp
        alias_method :sp_session, :raw_session

        def initialize(sp, raw_session, request, current_user)
          @sp = sp
          @raw_session = raw_session
          @request = request
          @current_user = current_user
        end
      end

    test_request = double(
      'test_request',
      session: raw_session,
      parameters: {},
      filtered_parameters: {},
    )

    test_controller_class.new(sp, raw_session, test_request, current_user)
  end

  describe '#mfa_expiration_interval' do
    let(:expected_aal_1_expiration) { 720.hours }
    let(:expected_aal_2_expiration) { 0.hours }

    context 'with no sp' do
      let(:sp) { nil }

      it { expect(test_controller.mfa_expiration_interval).to eq(expected_aal_1_expiration) }
    end

    context 'with an AAL2 sp' do
      let(:sp) { build(:service_provider, default_aal: 2) }

      context 'requesting AAL1' do
        let(:raw_session) { { acr_values: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF } }
        it { expect(test_controller.mfa_expiration_interval).to eq(expected_aal_1_expiration) }
      end

      context 'not requesting AAL' do
        let(:raw_session) { { acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF } }
        it { expect(test_controller.mfa_expiration_interval).to eq(expected_aal_2_expiration) }
      end
    end

    context 'with an IAL2 sp' do
      let(:sp) { build(:service_provider, ial: 2) }

      it { expect(test_controller.mfa_expiration_interval).to eq(expected_aal_2_expiration) }
    end

    context 'with an sp that is not AAL2 or IAL2' do
      let(:sp) { build(:service_provider) }

      context 'and AAL1 requested' do
        context 'with vtr' do
          let(:raw_session) { { vtr: ['C1'] } }

          it { expect(test_controller.mfa_expiration_interval).to eq(30.days) }
        end

        context 'with legacy acr' do
          let(:raw_session) { { acr_values: Saml::Idp::Constants::AAL1_AUTHN_CONTEXT_CLASSREF } }

          it { expect(test_controller.mfa_expiration_interval).to eq(30.days) }
        end
      end

      context 'and AAL2 requested' do
        context 'with vtr' do
          let(:raw_session) { { vtr: ['C2'] } }

          it { expect(test_controller.mfa_expiration_interval).to eq(expected_aal_2_expiration) }
        end

        context 'with legacy acr' do
          let(:raw_session) { { acr_values: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF } }

          it { expect(test_controller.mfa_expiration_interval).to eq(expected_aal_2_expiration) }
        end
      end
    end
  end
end
