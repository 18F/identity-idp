require 'rails_helper'

RSpec.describe AuthnContextResolver do
  let(:user) { build(:user) }

  context 'when the user uses a vtr param' do
    it 'parses the vtr param into requirements' do
      vtr = ['C2.Pb']

      result = AuthnContextResolver.new(
        user: user,
        service_provider: nil,
        vtr: vtr,
        acr_values: nil,
      ).result

      expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.P1.Pb')
      expect(result.aal2?).to eq(true)
      expect(result.phishing_resistant?).to eq(false)
      expect(result.hspd12?).to eq(false)
      expect(result.identity_proofing?).to eq(true)
      expect(result.facial_match?).to eq(true)
      expect(result.ialmax?).to eq(false)
      expect(result.enhanced_ipp?).to eq(false)
    end

    it 'parses the vtr param for enhanced ipp' do
      vtr = ['Pe']

      result = AuthnContextResolver.new(
        user: user,
        service_provider: nil,
        vtr: vtr,
        acr_values: nil,
      ).result

      expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.P1.Pe')
      expect(result.aal2?).to eq(true)
      expect(result.phishing_resistant?).to eq(false)
      expect(result.hspd12?).to eq(false)
      expect(result.identity_proofing?).to eq(true)
      expect(result.facial_match?).to eq(false)
      expect(result.ialmax?).to eq(false)
      expect(result.enhanced_ipp?).to eq(true)
    end

    it 'ignores any acr_values params that are passed' do
      vtr = ['C2.Pb']

      acr_values = [
        Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
        Saml::Idp::Constants::IAL_VERIFIED_ACR,
      ].join(' ')

      result = AuthnContextResolver.new(
        user: user,
        service_provider: nil,
        vtr: vtr,
        acr_values: acr_values,
      ).result

      expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.P1.Pb')
    end
  end

  context 'when the user uses a vtr param with multiple vectors' do
    context 'a facial match proofing vector and non-facial match proofing vector is present' do
      it 'returns a facial match requirement if the user can satisfy it' do
        user = create(:user, :proofed)
        user.active_profile.update!(idv_level: 'unsupervised_with_selfie')
        vtr = ['C2.Pb', 'C2.P1']

        result = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: vtr,
          acr_values: nil,
        ).result

        expect(result.expanded_component_values).to eq('C1.C2.P1.Pb')
        expect(result.facial_match?).to eq(true)
        expect(result.identity_proofing?).to eq(true)
      end

      it 'returns non-facial match vector if user has identity-proofed without facial match' do
        user = create(:user, :proofed)
        vtr = ['C2.Pb', 'C2.P1']

        result = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: vtr,
          acr_values: nil,
        ).result

        expect(result.expanded_component_values).to eq('C1.C2.P1')
        expect(result.facial_match?).to eq(false)
        expect(result.identity_proofing?).to eq(true)
      end

      it 'returns the first vector if the user has not proofed' do
        user = create(:user)
        vtr = ['C2.Pb', 'C2.P1']

        result = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: vtr,
          acr_values: nil,
        ).result

        expect(result.expanded_component_values).to eq('C1.C2.P1.Pb')
        expect(result.facial_match?).to eq(true)
        expect(result.identity_proofing?).to eq(true)
      end
    end

    context 'a non-facial match identity proofing vector is present' do
      it 'returns the identity-proofing requirement if the user can satisfy it' do
        user = create(:user, :proofed)
        vtr = ['C2.P1', 'C2']

        result = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: vtr,
          acr_values: nil,
        ).result

        expect(result.expanded_component_values).to eq('C1.C2.P1')
        expect(result.identity_proofing?).to eq(true)
      end

      it 'returns the no-proofing vector if the user cannot satisfy the ID-proofing requirement' do
        user = create(:user)
        vtr = ['C2.P1', 'C2']

        result = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: vtr,
          acr_values: nil,
        ).result

        expect(result.expanded_component_values).to eq('C1.C2')
        expect(result.identity_proofing?).to eq(false)
      end
    end
  end

  context 'when resolving acr_values' do
    let(:service_provider) { nil }
    subject do
      AuthnContextResolver.new(
        user: user,
        service_provider:,
        vtr: nil,
        acr_values: acr_values,
      )
    end

    let(:result) { subject.result }

    context 'with no service provider' do
      let(:acr_values) do
        [
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
        ].join(' ')
      end

      it 'parses an ACR value into requirements' do
        expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.facial_match?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end

      it 'returns the AAL value asserted' do
        expect(subject.asserted_aal_acr).to eq Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
      end

      context 'without an AAL ACR value' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
          ].join(' ')
        end

        it 'properly parses the ACR value ' do
          expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
          expect(result.aal2?).to eq(false)
          expect(result.phishing_resistant?).to eq(false)
          expect(result.hspd12?).to eq(false)
          expect(result.identity_proofing?).to eq(false)
          expect(result.facial_match?).to eq(false)
          expect(result.ialmax?).to eq(false)
          expect(result.enhanced_ipp?).to eq(false)
        end
      end

      context 'without an IAL ACR value' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          ].join(' ')
        end

        it 'properly parses an ACR value without an IAL ACR' do
          expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
          expect(result.aal2?).to eq(true)
          expect(result.phishing_resistant?).to eq(false)
          expect(result.hspd12?).to eq(false)
          expect(result.identity_proofing?).to eq(false)
          expect(result.facial_match?).to eq(false)
          expect(result.ialmax?).to eq(false)
          expect(result.enhanced_ipp?).to eq(false)
        end

        it 'returns the AAL value asserted' do
          expect(subject.asserted_aal_acr).to eq Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
        end
      end
    end

    context 'with an AAL2 service provider' do
      let(:service_provider) { build(:service_provider, default_aal: 2) }

      context 'an AAL value is present' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
          ].join(' ')
        end

        it 'uses the AAL ACR value' do
          expect(result.aal2?).to eq(false)
        end

        it 'returns the asserted aal value' do
          aal_value = Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF
          expect(subject.asserted_aal_acr).to eq aal_value
        end
      end

      context 'with no AAL ACR present' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
          ].join(' ')
        end

        it 'uses the default AAL2' do
          expect(result.aal2?).to eq(true)
          expect(result.phishing_resistant?).to eq(false)
        end

        it 'returns the asserted AAL2 value' do
          expect(subject.asserted_aal_acr).to eq Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
        end
      end
    end

    context 'with an AAL3 service provider' do
      let(:service_provider) { build(:service_provider, default_aal: 3) }

      context 'with no AAL ACR present' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
          ].join(' ')
        end

        it 'uses the default AAL at AAL 2 with phishing_resistance' do
          expect(result.aal2?).to eq(true)
          expect(result.phishing_resistant?).to eq(true)
        end

        it 'returns the asserted AAL2 value' do
          expect(subject.asserted_aal_acr).to eq(
            Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'with an AAL ACR value present' do
        let(:acr_values) do
          [
            'urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo',
          ].join(' ')
        end

        it 'does not use the default_aal value' do
          result = subject.result

          expect(result.aal2?).to eq(false)
        end

        it 'returns the asserted default AAL value' do
          expect(subject.asserted_aal_acr).to eq(
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end
    end

    context 'with an IAL2 service provider' do
      let(:service_provider) { build(:service_provider, ial: 2) }

      context 'if IAL ACR value is present' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ].join(' ')
        end

        it 'uses the IAL ACR if one is present' do
          expect(result.identity_proofing?).to be false
          expect(result.aal2?).to be false
        end

        it 'asserts the default AAL value' do
          expect(subject.asserted_aal_acr).to eq(
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end

      context 'when multiple IAL ACR values are present' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ].join(' ')
        end

        it 'uses the highest IAL ACR if one is present' do
          expect(result.identity_proofing?).to be true
          expect(result.aal2?).to be true
        end

        it 'asserts the AAL2 value, even though the ddefault aal value was passed in' do
          expect(subject.asserted_aal_acr).to eq Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
        end

        context 'when one of the acr values is unknown' do
          let(:acr_values) do
            [
              Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              'unknown-acr-value',
            ].join(' ')
          end

          it 'ignores the unknown value and uses the highest IAL ACR' do
            expect(result.identity_proofing?).to eq(true)
            expect(result.aal2?).to eq(true)
          end

          it 'asserts the AAL2 value, even though the ddefault aal value was passed in' do
            expect(subject.asserted_aal_acr).to eq Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
          end
        end
      end

      context 'if No IAL ACR is present' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ].join(' ')
        end

        it 'uses the defaul IAL' do
          expect(result.identity_proofing?).to be true
          expect(result.aal2?).to be true
        end

        it 'asserts the AAL2 value, even though the ddefault aal value was passed in' do
          expect(subject.asserted_aal_acr).to eq Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
        end
      end

      context 'when the only ACR value is unknown' do
        let(:acr_values) { 'unknown-acr-value' }

        it 'errors out as if there were no values' do
          expect { result }.to raise_error Vot::Parser::ParseException
        end
      end

      context 'when requesting facial match comparison' do
        let(:bio_acr_value) do
          Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF
        end

        let(:acr_values) do
          [
            bio_acr_value,
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ].join(' ')
        end

        it 'asserts the AAL2 value, even though the ddefault aal value was passed in' do
          expect(subject.asserted_aal_acr).to eq Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
        end

        context 'with facial match comparison is required' do
          context 'when user is not verified' do
            it 'sets facial_match to true' do
              expect(result.identity_proofing?).to be true
              expect(result.facial_match?).to be true
              expect(result.aal2?).to be true
              expect(result.two_pieces_of_fair_evidence?).to be true
            end
          end

          context 'when the user is already verified' do
            context 'without facial match comparison' do
              let(:user) { build(:user, :proofed) }

              it 'asserts facial_match as true' do
                expect(result.identity_proofing?).to be true
                expect(result.facial_match?).to be true
                expect(result.aal2?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
              end
            end

            context 'with facial match comparison' do
              let(:user) { build(:user, :proofed_with_selfie) }

              it 'asserts facial match comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.facial_match?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
                expect(result.aal2?).to be true
              end
            end
          end
        end

        context 'with facial match comparison is preferred' do
          let(:bio_acr_value) do
            Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF
          end

          context 'when the user is already verified' do
            context 'without facial match comparison' do
              let(:user) { build(:user, :proofed) }

              it 'falls back on proofing without facial match comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.facial_match?).to be false
                expect(result.two_pieces_of_fair_evidence?).to be false
                expect(result.aal2?).to be true
              end
            end

            context 'with facial match comparison' do
              let(:user) { build(:user, :proofed_with_selfie) }

              it 'asserts facial match comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.facial_match?).to be true
                expect(result.aal2?).to be true
              end
            end
          end

          context 'when the user has not yet been verified' do
            let(:user) { build(:user) }

            it 'asserts facial match comparison' do
              expect(result.identity_proofing?).to be true
              expect(result.facial_match?).to be true
              expect(result.aal2?).to be true
            end
          end
        end
      end
    end
  end

  context 'when resolving semantic acr_values' do
    context 'when no semantic ACR present' do
      let(:user) { build(:user) }

      it 'does not resolve legacy ACRs to semantic ACRs' do
        acr_values = [
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        ]

        resolver = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values.join(' '),
        )
        result = resolver.result

        expect(resolver.asserted_ial_acr).to eq(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)
        expect(result.component_names).to eq(acr_values)
        expect(result.to_h).to include(
          aal2?: false,
          facial_match?: false,
          enhanced_ipp?: false,
          hspd12?: false,
          ialmax?: false,
          identity_proofing?: false,
          phishing_resistant?: false,
        )
      end
    end

    context 'with no service provider' do
      it 'parses an ACR value into requirements' do
        acr_values = [
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
        ]

        resolver = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values.join(' '),
        )
        result = resolver.result

        expect(result.component_names).to eq(acr_values)
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.facial_match?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end

      it 'properly parses an ACR value without an AAL ACR' do
        acr_values = [
          Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
        ]

        resolver = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values.join(' '),
        )
        result = resolver.result

        expect(result.component_names).to eq(acr_values)
        expect(result.aal2?).to eq(false)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.facial_match?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end

      it 'properly parses an ACR value without an IAL ACR' do
        acr_values = [
          Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
        ]
        resolver = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values.join(' '),
        )
        result = resolver.result
        expect(result.component_names).to eq(acr_values)
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.facial_match?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end
    end

    context 'with an IAL2 service provider' do
      let(:service_provider) { create(:service_provider, :idv) }
      subject do
        AuthnContextResolver.new(
          user: user,
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values&.join(' '),
        )
      end

      let(:result) { subject.result }

      context 'if IAL ACR value is present' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        it 'uses the IAL ACR if one is present' do
          expect(result.identity_proofing?).to be false
          expect(result.aal2?).to be false
        end
      end

      context 'when multiple IAL ACR values are present' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
            Saml::Idp::Constants::IAL_VERIFIED_ACR,
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        it 'uses the highest IAL ACR if one is present' do
          expect(result.identity_proofing?).to be true
          expect(result.aal2?).to be true
        end

        context 'when one of the acr values is unknown' do
          let(:acr_values) do
            [
              Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
              Saml::Idp::Constants::IAL_VERIFIED_ACR,
              Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
              'unknown-acr-value',
            ]
          end

          it 'ignores the unknown value and uses the highest IAL ACR' do
            expect(result.identity_proofing?).to eq(true)
            expect(result.aal2?).to eq(true)
          end
        end
      end

      context 'if No IAL ACR is present' do
        let(:acr_values) do
          [
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        context 'when user is not verified' do
          let(:user) { build(:user, :fully_registered) }

          it "asserts #{Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF}" do
            expect(subject.asserted_ial_acr)
              .to eq(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)
            expect(result.identity_proofing?).to be true
            expect(result.aal2?).to be true
          end
        end

        context 'when user is verified' do
          let(:user) { build(:user, :proofed) }

          it "asserts #{Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF}" do
            expect(subject.asserted_ial_acr)
              .to eq(Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF)
          end
        end
      end

      context 'if requesting facial match comparison' do
        let(:bio_acr_value) do
          Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR
        end

        let(:acr_values) do
          [
            bio_acr_value,
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ]
        end

        before do
          allow_any_instance_of(ServiceProvider)
            .to receive(:facial_match_ial_allowed?)
            .and_return(true)
        end

        context 'with facial match comparison is required' do
          context 'when user is not verified' do
            it "asserts the resolved IAL as #{Saml::Idp::Constants::IAL_AUTH_ONLY_ACR}" do
              expect(subject.asserted_ial_acr)
                .to eq(Saml::Idp::Constants::IAL_AUTH_ONLY_ACR)
            end

            it 'sets facial_match to true' do
              expect(result.identity_proofing?).to be true
              expect(result.facial_match?).to be true
              expect(result.aal2?).to be true
              expect(result.two_pieces_of_fair_evidence?).to be true
              expect(result.ialmax?).to be false
            end
          end

          context 'when the user is already verified' do
            context 'without facial match comparison' do
              let(:user) { build(:user, :proofed) }

              it 'asserts facial_match as true' do
                expect(result.identity_proofing?).to be true
                expect(result.facial_match?).to be true
                expect(result.aal2?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
                expect(result.ialmax?).to be false
              end
            end

            context 'with facial match comparison' do
              let(:user) { build(:user, :proofed_with_selfie) }

              it 'asserts facial match comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.facial_match?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
                expect(result.aal2?).to be true
                expect(result.ialmax?).to be false
              end
            end
          end
        end

        context 'with facial match comparison is preferred' do
          let(:bio_acr_value) do
            Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR
          end

          context 'when the user is already verified' do
            context 'without facial match comparison' do
              let(:user) { build(:user, :proofed) }

              it 'falls back on proofing without facial match comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.facial_match?).to be false
                expect(result.two_pieces_of_fair_evidence?).to be false
                expect(result.aal2?).to be true
                expect(result.ialmax?).to be false
              end
            end

            context 'with facial match comparison' do
              let(:user) { build(:user, :proofed_with_selfie) }

              it 'asserts facial match comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.facial_match?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
                expect(result.aal2?).to be true
                expect(result.ialmax?).to be false
              end
            end
          end

          context 'when the user has not yet been verified' do
            let(:user) { build(:user) }

            it 'asserts facial match comparison' do
              expect(result.identity_proofing?).to be true
              expect(result.facial_match?).to be true
              expect(result.two_pieces_of_fair_evidence?).to be true
              expect(result.aal2?).to be true
              expect(result.ialmax?).to be false
            end
          end
        end
      end
    end
  end

  context 'with SSA forcing IAL2 values' do
    let(:sp) { build(:service_provider, :idv) }

    subject do
      AuthnContextResolver.new(
        user:,
        service_provider: sp,
        vtr: nil,
        acr_values:,
      )
    end
    before do
      allow(IdentityConfig.store).to receive(:allowed_ssa_force_ial2_providers)
        .and_return(sp.issuer)
    end

    context 'base idv requested' do
      let(:acr_values) { Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF }

      context 'there is no existing user' do
        let(:user) { nil }

        it 'requires ial2' do
          result = subject.result

          expect(result.identity_proofing?).to eq(true)
          expect(result.facial_match?).to eq(true)
        end
      end

      context 'the user is not proofed' do
        let(:user) { build(:user) }

        it 'requires ial2' do
          result = subject.result

          expect(result.identity_proofing?).to eq(true)
          expect(result.facial_match?).to eq(true)
        end
      end

      context 'the user is proofed with base idv' do
        let(:user) { build(:user, :proofed) }

        it 'requires ial2' do
          result = subject.result

          expect(result.identity_proofing?).to eq(true)
          expect(result.facial_match?).to eq(true)
        end
      end

      context 'the user is proofed with ial2' do
        let(:user) { build(:user, :proofed_with_selfie) }

        it 'requires ial2' do
          result = subject.result

          expect(result.identity_proofing?).to eq(true)
          expect(result.facial_match?).to eq(true)
        end
      end
    end

    context 'auth-only is requested' do
      let(:acr_values) { Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF }

      context 'there is no existing user' do
        let(:user) { nil }

        it 'requires ial1' do
          result = subject.result

          expect(result.identity_proofing?).to eq(false)
          expect(result.facial_match?).to eq(false)
        end
      end

      context 'the user is not proofed' do
        let(:user) { build(:user) }

        it 'requires ial1' do
          result = subject.result

          expect(result.identity_proofing?).to eq(false)
          expect(result.facial_match?).to eq(false)
        end
      end

      context 'the user is proofed with base idv' do
        let(:user) { build(:user, :proofed) }

        it 'requires ial1' do
          result = subject.result

          expect(result.identity_proofing?).to eq(false)
          expect(result.facial_match?).to eq(false)
        end
      end

      context 'the user is proofed with ial2' do
        let(:user) { build(:user, :proofed_with_selfie) }

        it 'requires ial1' do
          result = subject.result

          expect(result.identity_proofing?).to eq(false)
          expect(result.facial_match?).to eq(false)
        end
      end
    end
  end
end
