require 'rails_helper'

RSpec.describe AuthnContextResolver do
  context 'when the user uses a vtr param' do
    it 'parses the vtr param into requirements' do
      vtr = ['C2.Pb']

      result = AuthnContextResolver.new(
        service_provider: nil,
        vtr: vtr,
        acr_values: nil,
      ).resolve

      expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.P1.Pb')
      expect(result.aal2?).to eq(true)
      expect(result.phishing_resistant?).to eq(false)
      expect(result.hspd12?).to eq(false)
      expect(result.identity_proofing?).to eq(true)
      expect(result.biometric_comparison?).to eq(true)
      expect(result.ialmax?).to eq(false)
    end

    it 'ignores any acr_values params that are passed' do
      vtr = ['C2.Pb']

      acr_values = [
        'http://idmanagement.gov/ns/assurance/aal/2',
        'http://idmanagement.gov/ns/assurance/ial/2',
      ].join(' ')

      result = AuthnContextResolver.new(
        service_provider: nil,
        vtr: vtr,
        acr_values: acr_values,
      ).resolve

      expect(result.component_values.map(&:name).join('.')).to eq('C1.C2.P1.Pb')
    end
  end

  context 'when users uses an acr_values param' do
    context 'no service provider' do
      it 'parses an ACR value into requirements' do
        acr_values = [
          'http://idmanagement.gov/ns/assurance/aal/2',
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values,
        ).resolve

        expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.biometric_comparison?).to eq(false)
        expect(result.ialmax?).to eq(false)
      end

      it 'properly parses an ACR value without an AAL ACR' do
        acr_values = [
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values,
        ).resolve

        expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
        expect(result.aal2?).to eq(false)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.biometric_comparison?).to eq(false)
        expect(result.ialmax?).to eq(false)
      end

      it 'properly parses an ACR value without an IAL ACR' do
        acr_values = [
          'http://idmanagement.gov/ns/assurance/aal/2',
        ].join(' ')

        result = AuthnContextResolver.new(
          service_provider: nil,
          vtr: nil,
          acr_values: acr_values,
        ).resolve

        expect(result.component_values.map(&:name).join(' ')).to eq(acr_values)
        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
        expect(result.hspd12?).to eq(false)
        expect(result.identity_proofing?).to eq(false)
        expect(result.biometric_comparison?).to eq(false)
        expect(result.ialmax?).to eq(false)
      end
    end

    context 'AAL2 service provider' do
      it 'uses the AAL ACR if one is present' do
        service_provider = build(:service_provider, default_aal: 2)

        acr_values = [
          'http://idmanagement.gov/ns/assurance/aal/1',
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).resolve

        expect(result.aal2?).to eq(false)
      end

      it 'uses the default SP AAL at AAL 2 if no AAL ACR is present' do
        service_provider = build(:service_provider, default_aal: 2)

        acr_values = [
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).resolve

        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(false)
      end

      it 'uses the default SP AAL at AAL 3 if no AAL ACR is present' do
        service_provider = build(:service_provider, default_aal: 3)

        acr_values = [
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).resolve

        expect(result.aal2?).to eq(true)
        expect(result.phishing_resistant?).to eq(true)
      end

      it 'supports default AAL and overrides SP default' do
        service_provider = build(:service_provider, default_aal: 3)

        acr_values = [
          Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).resolve

        expect(result.aal2?).to eq(false)
        expect(result.phishing_resistant?).to eq(false)
      end
    end

    context 'IAL2 service provider' do
      it 'uses the IAL ACR if one is present' do
        service_provider = build(:service_provider, ial: 2)

        acr_values = [
          'http://idmanagement.gov/ns/assurance/aal/1',
          'http://idmanagement.gov/ns/assurance/ial/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).resolve

        expect(result.identity_proofing?).to eq(false)
        expect(result.aal2?).to eq(false)
      end

      it 'uses the defaul IAL if no IAL ACR is present' do
        service_provider = build(:service_provider, ial: 2)

        acr_values = [
          'http://idmanagement.gov/ns/assurance/aal/1',
        ].join(' ')

        result = AuthnContextResolver.new(
          service_provider: service_provider,
          vtr: nil,
          acr_values: acr_values,
        ).resolve

        expect(result.identity_proofing?).to eq(true)
        expect(result.aal2?).to eq(true)
      end
    end
  end
end
