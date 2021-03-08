require 'rails_helper'

RSpec.describe SpReturnUrlResolver do
  describe '#return_sp_url' do
    context 'for an SP with a redirect URI in the request URL' do
      it 'returns the redirect URI with error params and state' do
        redirect_uri = 'https://sp.gov/result'
        sp = build(
          :service_provider, redirect_uris: [redirect_uri], return_to_sp_url: 'https://sp.gov'
        )
        state = '1234abcd'

        resolver = described_class.new(
          service_provider: sp,
          oidc_state: state,
          oidc_redirect_uri: redirect_uri,
        )
        return_to_sp_url = resolver.return_to_sp_url
        return_to_sp_url_without_params = return_to_sp_url.split('?').first
        return_to_sp_url_params = UriService.params(return_to_sp_url)

        expect(return_to_sp_url_without_params).to eq(redirect_uri)
        expect(return_to_sp_url_params).to eq('state' => state, 'error' => 'access_denied')
      end

      it 'does not return the redirect URI if it is not in the SP redirect uri list' do
        redirect_uri = 'https://different-sp.gov/result'
        configured_return_to_sp_url = 'https://sp.gov'
        sp = build(
          :service_provider, redirect_uris: [], return_to_sp_url: configured_return_to_sp_url
        )
        state = '1234abcd'

        resolver = described_class.new(
          service_provider: sp,
          oidc_state: state,
          oidc_redirect_uri: redirect_uri,
        )
        return_to_sp_url = resolver.return_to_sp_url

        expect(return_to_sp_url).to eq(configured_return_to_sp_url)
      end
    end

    context 'for an SP without a redirect URI in the request URL' do
      it 'returns the return URL specified in the config' do
        configured_return_to_sp_url = 'https://sp.gov/return_to_sp'
        sp = build(:service_provider, return_to_sp_url: configured_return_to_sp_url)

        resolver = described_class.new(service_provider: sp)
        return_to_sp_url = resolver.return_to_sp_url

        expect(return_to_sp_url).to eq(configured_return_to_sp_url)
      end
    end

    context 'for an SP without a redirect URI or return URL in the config' do
      it 'returns the ACS URL without a path for a SAML SP' do
        acs_url = 'https://sp.gov/acs_url'
        sp = build(:service_provider, redirect_uris: [], return_to_sp_url: nil, acs_url: acs_url)

        resolver = described_class.new(service_provider: sp)
        return_to_sp_url = resolver.return_to_sp_url

        expect(return_to_sp_url).to eq('https://sp.gov/')
      end

      it 'returns the first redirect URI without a path for an OIDC SP' do
        redirect_uri = 'https://sp.gov/resut'
        sp = build(:service_provider, redirect_uris: [redirect_uri], return_to_sp_url: nil)

        resolver = described_class.new(service_provider: sp)
        return_to_sp_url = resolver.return_to_sp_url

        expect(return_to_sp_url).to eq('https://sp.gov/')
      end
    end
  end

  describe '#failure_to_proof_url' do
    it 'return the failure to proof url if one is registered' do
      configured_failure_to_proof_url = 'https://sp.gov/failure_to_proof'
      configured_return_to_sp_url = 'https://sp.gov/return_to_sp'
      sp = build(
        :service_provider,
        return_to_sp_url: configured_return_to_sp_url,
        failure_to_proof_url: configured_failure_to_proof_url,
      )

      resolver = described_class.new(service_provider: sp)
      failure_to_proof_url = resolver.failure_to_proof_url

      expect(failure_to_proof_url).to eq(configured_failure_to_proof_url)
    end

    it 'returns the return to sp url if no failure to proof url is registered' do
      configured_return_to_sp_url = 'https://sp.gov/return_to_sp'
      sp = build(
        :service_provider,
        return_to_sp_url: configured_return_to_sp_url,
        failure_to_proof_url: nil,
      )

      resolver = described_class.new(service_provider: sp)
      failure_to_proof_url = resolver.failure_to_proof_url

      expect(failure_to_proof_url).to eq(configured_return_to_sp_url)
    end

    it 'returns the returns to sp url if the failure to proof url is an empty string' do
      configured_return_to_sp_url = 'https://sp.gov/return_to_sp'
      sp = build(
        :service_provider,
        return_to_sp_url: configured_return_to_sp_url,
        failure_to_proof_url: '',
      )

      resolver = described_class.new(service_provider: sp)
      failure_to_proof_url = resolver.failure_to_proof_url

      expect(failure_to_proof_url).to eq(configured_return_to_sp_url)
    end
  end
end
