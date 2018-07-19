require 'rails_helper'

RSpec.describe OpenidConnectRedirector do
  include Rails.application.routes.url_helpers

  let(:redirect_uri) { 'http://localhost:7654/' }
  let(:state) { SecureRandom.hex }
  let(:service_provider) { ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:sp:server') }
  let(:errors) { ActiveModel::Errors.new(nil) }

  subject(:redirector) do
    OpenidConnectRedirector.new(
      redirect_uri: redirect_uri,
      service_provider: service_provider,
      state: state,
      errors: errors
    )
  end

  describe '.from_request_url' do
    it 'builds a redirector from an OpenID request_url' do
      request_url = openid_connect_authorize_url(
        client_id: service_provider.issuer,
        redirect_uri: redirect_uri,
        state: state
      )

      result = OpenidConnectRedirector.from_request_url(request_url)

      expect(result).to be_a(OpenidConnectRedirector)
      expect(result.send(:redirect_uri)).to eq(redirect_uri)
      expect(result.send(:service_provider)).to eq(service_provider)
      expect(result.send(:state)).to eq(state)
    end
  end

  describe '#validate' do
    context 'with a redirect_uri that spoofs a hostname' do
      let(:redirect_uri) { 'https://example.com.evilish.com/' }

      it 'is invalid' do
        redirector.validate
        expect(errors[:redirect_uri]).
          to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))
      end
    end

    context 'with a valid redirect_uri' do
      let(:redirect_uri) { 'http://localhost:7654/result/more/extra' }
      it 'is valid' do
        redirector.validate
        expect(errors).to be_empty
      end
    end

    context 'with a malformed redirect_uri' do
      let(:redirect_uri) { ':aaaa' }
      it 'has errors' do
        redirector.validate
        expect(errors[:redirect_uri]).
          to include(t('openid_connect.authorization.errors.redirect_uri_invalid'))
      end
    end

    context 'with a redirect_uri not registered to the service provider' do
      let(:redirect_uri) { 'http://localhost:3000/test' }
      it 'has errors' do
        redirector.validate
        expect(errors[:redirect_uri]).
          to include(t('openid_connect.authorization.errors.redirect_uri_no_match'))
      end
    end
  end

  describe '#success_redirect_uri' do
    it 'adds the code and state to the URL' do
      code = SecureRandom.hex
      expect(redirector.success_redirect_uri(code: code)).
        to eq(URIService.add_params(redirect_uri, code: code, state: state))
    end
  end

  describe '#decline_redirect_uri' do
    it 'adds the state and access_denied to the URL' do
      expect(redirector.decline_redirect_uri).
        to eq(URIService.add_params(redirect_uri, state: state, error: 'access_denied'))
    end
  end

  describe '#error_redirect_uri' do
    before { expect(errors).to receive(:full_messages).and_return(['some attribute is missing']) }

    it 'adds the errors to the URL' do
      expect(redirector.error_redirect_uri).
        to eq(URIService.add_params(redirect_uri,
                                    state: state,
                                    error: 'invalid_request',
                                    error_description: 'some attribute is missing'))
    end
  end

  describe '#logout_redirect_uri' do
    it 'adds the state to the URL' do
      expect(redirector.logout_redirect_uri).
        to eq(URIService.add_params(redirect_uri, state: state))
    end
  end

  describe '#validated_input_redirect_uri' do
    let(:service_provider) { ServiceProvider.new(redirect_uris: redirect_uris, active: true) }

    subject(:validated_input_redirect_uri) { redirector.validated_input_redirect_uri }

    context 'when the service provider has no redirect URIs' do
      let(:redirect_uris) { [] }

      it 'is nil' do
        expect(validated_input_redirect_uri).to be_nil
      end
    end

    context 'when the service provider has 2 redirect URIs' do
      let(:redirect_uris) { %w[http://localhost:1234/result my-app://result] }

      context 'when a URL matching the first redirect_uri is passed in' do
        let(:redirect_uri) { 'http://localhost:1234/result/more' }

        it 'is that URL' do
          expect(validated_input_redirect_uri).to eq(redirect_uri)
        end
      end

      context 'when a URL matching the second redirect_uri is passed in' do
        let(:redirect_uri) { 'my-app://result/more' }

        it 'is that URL' do
          expect(validated_input_redirect_uri).to eq(redirect_uri)
        end
      end

      context 'when a URL matching the neither redirect_uri is passed in' do
        let(:redirect_uri) { 'https://example.com' }

        it 'is nil' do
          expect(validated_input_redirect_uri).to be_nil
        end
      end
    end
  end
end
