require 'rails_helper'

describe SamlRequestValidator do
  describe '#call' do
    context 'valid authentication context and service provider' do
      it 'returns FormResponse with success: true' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        authn_context = Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
        )

        expect(FormResponse).to have_received(:new).
          with(success: true, errors: {}, extra: extra)
      end
    end

    context 'valid authentication context and invalid service provider' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.from_issuer('foo')
        authn_context = Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
        }
        errors = {
          service_provider: [t('errors.messages.unauthorized_service_provider')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'valid authentication context and unauthorized nameid format' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        authn_context = Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
        }
        errors = {
          nameid_format: [t('errors.messages.unauthorized_nameid_format')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'valid authentication context and authorized nameid format for SP' do
      it 'returns FormResponse with success: true' do
        sp = ServiceProvider.from_issuer('https://rp1.serviceprovider.com/auth/saml/metadata')
        authn_context = Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
        )

        expect(FormResponse).to have_received(:new).
          with(success: true, errors: {}, extra: extra)
      end
    end

    context 'invalid authentication context and valid service provider' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        authn_context = 'LOA11'
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
        }
        errors = {
          authn_context: [t('errors.messages.unauthorized_authn_context')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'invalid authentication context and invalid service provider' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.from_issuer('foo')
        authn_context = 'LOA11'
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
        }
        errors = {
          authn_context: [t('errors.messages.unauthorized_authn_context')],
          service_provider: [t('errors.messages.unauthorized_service_provider')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end
  end
end
