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
end
