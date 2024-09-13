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
      expect(result.biometric_comparison?).to eq(true)
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
      expect(result.biometric_comparison?).to eq(false)
      expect(result.ialmax?).to eq(false)
      expect(result.enhanced_ipp?).to eq(true)
    end

    it 'ignores any acr_values params that are passed' do
      vtr = ['C2.Pb']

      acr_values = [
        'http://idmanagement.gov/ns/assurance/aal/2',
        'http://idmanagement.gov/ns/assurance/ial/2',
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
    context 'a biometric proofing vector and non-biometric proofing vector is present' do
      it 'returns a biometric requirement if the user can satisfy it' do
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
        expect(result.biometric_comparison?).to eq(true)
        expect(result.identity_proofing?).to eq(true)
      end

      it 'returns the non-biometric vector if the user has identity-proofed without biometric' do
        user = create(:user, :proofed)
        vtr = ['C2.Pb', 'C2.P1']

        result = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: vtr,
          acr_values: nil,
        ).result

        expect(result.expanded_component_values).to eq('C1.C2.P1')
        expect(result.biometric_comparison?).to eq(false)
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
        expect(result.biometric_comparison?).to eq(true)
        expect(result.identity_proofing?).to eq(true)
      end
    end

    context 'a non-biometric identity proofing vector is present' do
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
    context 'with no service provider' do
      it 'parses an ACR value into requirements' do
        acr_values = [
          'http://idmanagement.gov/ns/assurance/aal/2',
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values,
        ).result

        expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.biometric_comparison?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end

      it 'properly parses an ACR value without an AAL ACR' do
        acr_values = [
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values,
        ).result

        expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
        expect(result.aal2?).to eq(false)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.biometric_comparison?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end

      it 'properly parses an ACR value without an IAL ACR' do
        acr_values = [
          'http://idmanagement.gov/ns/assurance/aal/2',
        ].join(' ')

        result = AuthnContextResolver.new(
          user: user,
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values,
        ).result

        expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.biometric_comparison?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end
    end

    context 'with an AAL2 service provider' do
      it 'uses the AAL ACR if one is present' do
        service_provider = build(:service_provider, default_aal: 2)

        acr_values = [
          'http://idmanagement.gov/ns/assurance/aal/1',
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          user: user,
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).result

        expect(result.aal2?).to eq(false)
      end

      it 'uses the default AAL at AAL 2 if no AAL ACR is present' do
        service_provider = build(:service_provider, default_aal: 2)

        acr_values = [
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          user: user,
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).result

        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
      end

      it 'uses the default AAL at AAL 3 if no AAL ACR is present' do
        service_provider = build(:service_provider, default_aal: 3)

        acr_values = [
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          user: user,
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).result

        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(true)
      end

      it 'does not use the default AAL if the default AAL ACR value is present' do
        service_provider = build(:service_provider, default_aal: 2)

        acr_values = [
          'urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo',
        ].join(' ')

        result = AuthnContextResolver.new(
          user: user,
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).result

        expect(result.aal2?).to eq(false)
      end
    end

    context 'with an IAL2 service provider' do
      let(:service_provider) { build(:service_provider, ial: 2) }
      subject do
        AuthnContextResolver.new(
          user: user,
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        )
      end

      let(:result) { subject.result }

      context 'if IAL ACR value is present' do
        let(:acr_values) do
          [
            'http://idmanagement.gov/ns/assurance/ial/1',
            'http://idmanagement.gov/ns/assurance/aal/1',
          ].join(' ')
        end

        it 'uses the IAL ACR if one is present' do
          expect(result.identity_proofing?).to be false
          expect(result.aal2?).to be false
        end
      end

      context 'if multiple IAL ACR values are present' do
        let(:acr_values) do
          [
            'http://idmanagement.gov/ns/assurance/ial/1',
            'http://idmanagement.gov/ns/assurance/ial/2',
            'http://idmanagement.gov/ns/assurance/aal/1',
          ].join(' ')
        end

        it 'uses the highest IAL ACR if one is present' do
          expect(result.identity_proofing?).to be true
          expect(result.aal2?).to be true
        end
      end

      context 'if No IAL ACR is present' do
        let(:acr_values) do
          [
            'http://idmanagement.gov/ns/assurance/aal/1',
          ].join(' ')
        end

        it 'uses the defaul IAL' do
          expect(result.identity_proofing?).to be true
          expect(result.aal2?).to be true
        end
      end

      context 'if requesting biometric comparison' do
        let(:bio_value) { 'required' }
        let(:acr_values) do
          [
            "http://idmanagement.gov/ns/assurance/ial/2?bio=#{bio_value}",
            'http://idmanagement.gov/ns/assurance/aal/1',
          ].join(' ')
        end

        context 'with biometric comparison is required' do
          context 'when user is not verified' do
            it 'sets biometric_comparison to true' do
              expect(result.identity_proofing?).to be true
              expect(result.biometric_comparison?).to be true
              expect(result.aal2?).to be true
              expect(result.two_pieces_of_fair_evidence?).to be true
            end
          end

          context 'when the user is already verified' do
            context 'without biometric comparison' do
              let(:user) { build(:user, :proofed) }

              it 'asserts biometric_comparison as true' do
                expect(result.identity_proofing?).to be true
                expect(result.biometric_comparison?).to be true
                expect(result.aal2?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
              end
            end

            context 'with biometric comparison' do
              let(:user) { build(:user, :proofed_with_selfie) }

              it 'asserts biometric comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.biometric_comparison?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
                expect(result.aal2?).to be true
              end
            end
          end
        end

        context 'with biometric comparison is preferred' do
          let(:bio_value) { 'preferred' }

          context 'when the user is already verified' do
            context 'without biometric comparison' do
              let(:user) { build(:user, :proofed) }

              it 'falls back on proofing without biometric comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.biometric_comparison?).to be false
                expect(result.two_pieces_of_fair_evidence?).to be false
                expect(result.aal2?).to be true
              end
            end

            context 'with biometric comparison' do
              let(:user) { build(:user, :proofed_with_selfie) }

              it 'asserts biometric comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.biometric_comparison?).to be true
                expect(result.aal2?).to be true
              end
            end
          end

          context 'when the user has not yet been verified' do
            let(:user) { build(:user) }

            it 'asserts biometric comparison' do
              expect(result.identity_proofing?).to be true
              expect(result.biometric_comparison?).to be true
              expect(result.aal2?).to be true
            end
          end
        end
      end
    end
  end

  context 'when resolving semantic acr_values' do
    before do
      allow(IdentityConfig.store).
        to receive(:feature_valid_authn_contexts_semantic_enabled).
        and_return(true)
      allow_any_instance_of(ServiceProvider).
        to receive(:semantic_authn_contexts_allowed?).
        and_return(true)

      stub_const(
        'Saml::Idp::Constants::VALID_AUTHN_CONTEXTS',
        IdentityConfig.store.valid_authn_contexts_semantic,
      )
    end

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
          biometric_comparison?: false,
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
          'http://idmanagement.gov/ns/assurance/aal/2',
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
        expect(result.biometric_comparison?).to eq(false)
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
        expect(result.biometric_comparison?).to eq(false)
        expect(result.ialmax?).to eq(false)
        expect(result.enhanced_ipp?).to eq(false)
      end

      it 'properly parses an ACR value without an IAL ACR' do
        acr_values = [
          'http://idmanagement.gov/ns/assurance/aal/2',
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
        expect(result.biometric_comparison?).to eq(false)
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
            'http://idmanagement.gov/ns/assurance/ial/1',
            'http://idmanagement.gov/ns/assurance/aal/1',
          ]
        end

        it 'uses the IAL ACR if one is present' do
          expect(result.identity_proofing?).to be false
          expect(result.aal2?).to be false
        end
      end

      context 'if multiple IAL ACR values are present' do
        let(:acr_values) do
          [
            'http://idmanagement.gov/ns/assurance/ial/1',
            'urn:acr.login.gov:verified',
            'http://idmanagement.gov/ns/assurance/aal/1',
          ]
        end

        it 'uses the highest IAL ACR if one is present' do
          expect(result.identity_proofing?).to be true
          expect(result.aal2?).to be true
        end
      end

      context 'if No IAL ACR is present' do
        let(:acr_values) do
          [
            'http://idmanagement.gov/ns/assurance/aal/1',
          ]
        end

        context 'when user is not verified' do
          let(:user) { build(:user, :fully_registered) }

          it "asserts #{Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF}" do
            expect(subject.asserted_ial_acr).
              to eq(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)
            expect(result.identity_proofing?).to be true
            expect(result.aal2?).to be true
          end
        end

        context 'when user is verified' do
          let(:user) { build(:user, :proofed) }

          it "asserts #{Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF}" do
            expect(subject.asserted_ial_acr).
              to eq(Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF)
          end
        end
      end

      context 'if requesting biometric comparison' do
        let(:bio_value) { 'required' }
        let(:acr_values) do
          [
            "urn:acr.login.gov:verified-facial-match-#{bio_value}",
            'http://idmanagement.gov/ns/assurance/aal/1',
          ]
        end

        before do
          allow_any_instance_of(ServiceProvider).
            to receive(:biometric_ial_allowed?).
            and_return(true)
        end

        context 'with biometric comparison is required' do
          context 'when user is not verified' do
            it "asserts the resolved IAL as #{Saml::Idp::Constants::IAL_AUTH_ONLY_ACR}" do
              expect(subject.asserted_ial_acr).
                to eq(Saml::Idp::Constants::IAL_AUTH_ONLY_ACR)
            end

            it 'sets biometric_comparison to true' do
              expect(result.identity_proofing?).to be true
              expect(result.biometric_comparison?).to be true
              expect(result.aal2?).to be true
              expect(result.two_pieces_of_fair_evidence?).to be true
              expect(result.ialmax?).to be false
            end
          end

          context 'when the user is already verified' do
            context 'without biometric comparison' do
              let(:user) { build(:user, :proofed) }

              it 'asserts biometric_comparison as true' do
                expect(result.identity_proofing?).to be true
                expect(result.biometric_comparison?).to be true
                expect(result.aal2?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
                expect(result.ialmax?).to be false
              end
            end

            context 'with biometric comparison' do
              let(:user) { build(:user, :proofed_with_selfie) }

              it 'asserts biometric comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.biometric_comparison?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
                expect(result.aal2?).to be true
                expect(result.ialmax?).to be false
              end
            end
          end
        end

        context 'with biometric comparison is preferred' do
          let(:bio_value) { 'preferred' }

          context 'when the user is already verified' do
            context 'without biometric comparison' do
              let(:user) { build(:user, :proofed) }

              it 'falls back on proofing without biometric comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.biometric_comparison?).to be false
                expect(result.two_pieces_of_fair_evidence?).to be false
                expect(result.aal2?).to be true
                expect(result.ialmax?).to be false
              end
            end

            context 'with biometric comparison' do
              let(:user) { build(:user, :proofed_with_selfie) }

              it 'asserts biometric comparison' do
                expect(result.identity_proofing?).to be true
                expect(result.biometric_comparison?).to be true
                expect(result.two_pieces_of_fair_evidence?).to be true
                expect(result.aal2?).to be true
                expect(result.ialmax?).to be false
              end
            end
          end

          context 'when the user has not yet been verified' do
            let(:user) { build(:user) }

            it 'asserts biometric comparison' do
              expect(result.identity_proofing?).to be true
              expect(result.biometric_comparison?).to be true
              expect(result.two_pieces_of_fair_evidence?).to be true
              expect(result.aal2?).to be true
              expect(result.ialmax?).to be false
            end
          end
        end
      end
    end
  end
end
