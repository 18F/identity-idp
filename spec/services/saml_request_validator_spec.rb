require 'rails_helper'

describe SamlRequestValidator do

  describe '#call' do
    context 'valid authn context and sp and authorized nameID format' do
      it 'returns FormResponse with success: true' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        authn_context = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(FormResponse).to have_received(:new).
          with(success: true, errors: {}, extra: extra)
      end
    end

    context 'valid authn context and invalid sp and authorized nameID format' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.from_issuer('foo')
        authn_context = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
        }
        errors = {
          service_provider: [t('errors.messages.unauthorized_service_provider')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'valid authn context and unauthorized nameid format' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        authn_context = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
        }
        errors = {
          nameid_format: [t('errors.messages.unauthorized_nameid_format')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'valid authn context and authorized email nameid format for SP' do
      it 'returns FormResponse with success: true' do
        sp = ServiceProvider.from_issuer('https://rp1.serviceprovider.com/auth/saml/metadata')
        authn_context = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(FormResponse).to have_received(:new).
          with(success: true, errors: {}, extra: extra)
      end

      it 'returns FormResponse with success: true for ial2 on ial:2 sp' do
        sp = ServiceProvider.from_issuer('https://rp1.serviceprovider.com/auth/saml/metadata')
        sp.ial = 2
        authn_context = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(FormResponse).to have_received(:new).
          with(success: true, errors: {}, extra: extra)
      end
    end

    context 'invalid authn context and valid sp and authorized nameID format' do
      it 'returns FormResponse with success: false for unknown authn context' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        authn_context = 'IAL1'
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
        }
        errors = {
          authn_context: [t('errors.messages.unauthorized_authn_context')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end

      it 'returns FormResponse with success: false for ial2 on an ial:1 sp' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        sp.ial = 1
        authn_context = Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
        }
        errors = {
          authn_context: [t('errors.messages.unauthorized_authn_context')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'invalid authn context and invalid sp and authorized nameID format' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.from_issuer('foo')
        authn_context = 'IAL1'
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
        }
        errors = {
          authn_context: [t('errors.messages.unauthorized_authn_context')],
          service_provider: [t('errors.messages.unauthorized_service_provider')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end

    context 'valid authn context and sp and unauthorized nameID format' do
      it 'returns FormResponse with success: true' do
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        authn_context = Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        allow(FormResponse).to receive(:new)
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
        }
        errors = {
          nameid_format: [t('errors.messages.unauthorized_nameid_format')],
        }

        SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(FormResponse).to have_received(:new).
          with(success: false, errors: errors, extra: extra)
      end
    end
  end
end
