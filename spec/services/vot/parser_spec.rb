require 'rails_helper'

RSpec.describe Component::Parser do
  describe '#parse' do
    context 'when neither a VtR nor ACR values are provided' do
      it 'raises an error' do
        expect { Component::Parser.new.parse }
          .to raise_error(
            Component::Parser::ParseException,
            'Component parser called without ACR values',
          )
      end
    end

    context 'with just a VtR value provided' do
      it 'raises an error' do
        vector_of_trust = 'Pb'
        expect { Component::Parser.new(vector_of_trust:).parse }
          .to raise_error(
            Component::Parser::ParseException,
            'Component parser called without ACR values',
          )
      end
    end

    context 'when input components are completely expanded' do
      let(:acr_values) do
        [
          Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::IAL_VERIFIED_ACR,
        ].join(' ')
      end

      it 'parses ACR values to component values' do
        result = Component::Parser.new(acr_values:).parse

        expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(true)
        expect(result.identity_proofing?).to eq(true)
        expect(result.facial_match?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end
    end

    context 'when two pieces of fair evidence is required' do
      let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR }

      it 'adds the two pieces of fair evidence requirement' do
        result = Component::Parser.new(acr_values:).parse

        expect(result.expanded_component_values).to eq(acr_values)
        expect(result.two_pieces_of_fair_evidence?).to eq(true)
      end
    end

    context 'when input includes unrecognized components' do
      let(:acr_values) { 'unknown-acr-value' }

      context 'only an unknown acr_value is passed in' do
        it 'raises an exception' do
          expect { Component::Parser.new(acr_values:).parse }.to raise_exception(
            Component::Parser::ParseException,
            'Component parser called without ACR values',
          )
        end

        context 'when a known and valid acr_value is passed in as well' do
          let(:acr_values) do
            [
              'unknown-acr-value',
              Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            ].join(' ')
          end

          it 'parses ACR values to component values' do
            result = Component::Parser.new(acr_values:).parse

            expect(result.component_values.map(&:name).join(' ')).to eq(
              Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            )
            expect(result.aal2?).to eq(false)
            expect(result.phishing_resistant?).to eq(false)
            expect(result.hspd12?).to eq(false)
            expect(result.identity_proofing?).to eq(false)
            expect(result.facial_match?).to eq(false)
            expect(result.ialmax?).to eq(false)
            expect(result.enhanced_ipp?).to eq(false)
          end

          context 'with semantic acr_values' do
            let(:acr_values) do
              [
                'unknown-acr-value',
                Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
              ].join(' ')
            end

            it 'parses ACR values to component values' do
              result = Component::Parser.new(acr_values:).parse

              expect(result.component_values.map(&:name).join(' ')).to eq(
                Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
              )
              expect(result.aal2?).to eq(false)
              expect(result.phishing_resistant?).to eq(false)
              expect(result.hspd12?).to eq(false)
              expect(result.identity_proofing?).to eq(false)
              expect(result.facial_match?).to eq(false)
              expect(result.ialmax?).to eq(false)
              expect(result.enhanced_ipp?).to eq(false)
            end
          end
        end
      end
    end

    context 'when input include duplicate components' do
      let(:acr_values) do
        [
          Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::IAL_VERIFIED_ACR,
          Saml::Idp::Constants::IAL_VERIFIED_ACR,
        ].join(' ')
      end

      it 'raises an exception' do
        expect { Component::Parser.new(acr_values:).parse }.to raise_exception(
          Component::Parser::DuplicateComponentsException,
        )
      end
    end
  end
end
