require 'rails_helper'

module FederatedProtocols
  RSpec.describe Saml do
    let(:authn_contexts) { [] }
    let(:saml_request) { instance_double(SamlIdp::Request) }

    subject { FederatedProtocols::Saml.new saml_request }

    before do
      allow(saml_request).to receive(:requested_authn_contexts).and_return(authn_contexts)
    end

    describe '#aal' do
      context 'when no aal context is requested' do
        it 'returns nil' do
          expect(subject.aal).to be_nil
        end
      end

      context 'when the only context requested is aal' do
        let(:aal) { 'http://idmanagement.gov/ns/assurance/aal/2' }
        let(:authn_contexts) { [aal] }

        it 'returns the requested aal' do
          expect(subject.aal).to eq(aal)
        end
      end

      context 'when multiple contexts are requested including aal' do
        let(:aal) { 'http://idmanagement.gov/ns/assurance/aal/2' }
        let(:ial) { 'http://idmanagement.gov/ns/assurance/ial/1' }
        let(:authn_contexts) { [ial, aal] }

        it 'returns the requested aal' do
          expect(subject.aal).to eq(aal)
        end
      end

      context 'when the requested aal is the legacy default class ref' do
        let(:aal) { ::Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF }
        let(:authn_contexts) { [aal] }

        it 'returns it' do
          expect(subject.aal).to eq(aal)
        end
      end

      context 'when an aal class ref carries a second value after whitespace' do
        let(:authn_contexts) do
          [
            "#{::Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF} " \
            "#{::Saml::Idp::Constants::IAL_VERIFIED_ACR}",
            "#{::Saml::Idp::Constants::IAL_VERIFIED_ACR}\t" \
            "#{::Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF}",
            ::Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        it 'does not treat it as an aal' do
          expect(subject.aal).to be_nil
        end
      end
    end

    describe '#acr_values' do
      before do
        allow(saml_request).to receive(:service_provider).and_return(nil)
        allow(saml_request).to receive(:requested_authn_context_comparison).and_return('exact')
      end

      context 'when an aal class ref carries a second value after whitespace' do
        let(:authn_contexts) do
          [
            "#{::Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF} " \
            "#{::Saml::Idp::Constants::IAL_VERIFIED_ACR}",
            ::Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        it 'carries only the exactly requested values' do
          expect(subject.acr_values).to eq(::Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)
        end
      end
    end

    describe '#requested_ial_authn_context' do
      context 'when no ial context is requested' do
        it 'returns nil' do
          expect(subject.requested_ial_authn_context).to be_nil
        end
      end

      context 'when the only context requested is ial' do
        let(:ial) { 'http://idmanagement.gov/ns/assurance/ial/2' }
        let(:authn_contexts) { [ial] }

        it 'returns the requested ial' do
          expect(subject.requested_ial_authn_context).to eq(ial)
        end
      end

      context 'when multiple contexts are requested including ial' do
        let(:aal) { 'http://idmanagement.gov/ns/assurance/aal/2' }
        let(:ial) { 'http://idmanagement.gov/ns/assurance/ial/1' }
        let(:authn_contexts) { [ial, aal] }

        it 'returns the requested ial' do
          expect(subject.requested_ial_authn_context).to eq(ial)
        end
      end
    end
  end
end
