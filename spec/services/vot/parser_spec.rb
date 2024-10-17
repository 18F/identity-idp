require 'rails_helper'

RSpec.describe Vot::Parser do
  describe '#parse' do
    context 'when neither a VtR nor ACR values are provided' do
      it 'raises an error' do
        expect { Vot::Parser.new(vector_of_trust: nil, acr_values: nil).parse }.
          to raise_error(Vot::Parser::ParseException, 'VoT parser called without VoT or ACR values')
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
        result = Vot::Parser.new(acr_values:).parse

        expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(true)
        expect(result.identity_proofing?).to eq(true)
        expect(result.facial_match?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end

      context 'with vectors of trust' do
        it 'returns the vector along with requirements' do
          vector_of_trust = 'C1.C2.Cb'

          result = Vot::Parser.new(vector_of_trust:).parse

          expect(result.expanded_component_values).to eq('C1.C2.Cb')
          expect(result.aal2?).to eq(true)
          expect(result.phishing_resistant?).to eq(false)
          expect(result.hspd12?).to eq(true)
          expect(result.identity_proofing?).to eq(false)
          expect(result.facial_match?).to eq(false)
          expect(result.ialmax?).to eq(false)
          expect(result.enhanced_ipp?).to eq(false)
        end
      end
    end

    context 'when a component value has implied components' do
      it 'adds the implied components' do
        vector_of_trust = 'Pb'

        result = Vot::Parser.new(vector_of_trust:).parse

        expect(result.expanded_component_values).to eq('C1.C2.P1.Pb')
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(true)
        expect(result.facial_match?).to eq(true)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end

      it 'adds the Enhanced In Person Proofing components' do
        vector_of_trust = 'Pe'

        result = Vot::Parser.new(vector_of_trust:).parse

        expect(result.expanded_component_values).to eq('C1.C2.P1.Pe')
        expect(result.enhanced_ipp?).to eq(true)
      end
    end

    context 'when two pieces of fair evidence is required' do
      let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR }

      it 'adds the two pieces of fair evidence requirement' do
        result = Vot::Parser.new(acr_values:).parse

        expect(result.expanded_component_values).to eq(acr_values)
        expect(result.two_pieces_of_fair_evidence?).to eq(true)
      end

      context 'with vectors of trust' do
        it 'adds the two pieces of fair evidence components' do
          vector_of_trust = 'Pb'

          result = Vot::Parser.new(vector_of_trust:).parse

          expect(result.expanded_component_values).to eq('C1.C2.P1.Pb')
          expect(result.two_pieces_of_fair_evidence?).to eq(true)
        end
      end
    end

    context 'when input includes unrecognized components' do
      let(:acr_values) { 'i-am-not-an-acr-value' }
      it 'raises an exception' do
        expect { Vot::Parser.new(acr_values:).parse }.to raise_exception(
          Vot::Parser::UnsupportedComponentsException,
          /'i-am-not-an-acr-value'$/,
        )
      end

      context 'with vectors of trust' do
        it 'raises an exception' do
          vector_of_trust = 'C1.C2.Xx'

          expect { Vot::Parser.new(vector_of_trust:).parse }.to raise_exception(
            Vot::Parser::UnsupportedComponentsException,
            /'Xx'$/,
          )
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
        expect { Vot::Parser.new(acr_values:).parse }.to raise_exception(
          Vot::Parser::DuplicateComponentsException,
        )
      end

      context 'with vectors of trust' do
        it 'raises an exception' do
          vector_of_trust = 'C1.C1'
          expect { Vot::Parser.new(vector_of_trust:).parse }.to raise_exception(
            Vot::Parser::DuplicateComponentsException,
          )
        end
      end
    end
  end
end
