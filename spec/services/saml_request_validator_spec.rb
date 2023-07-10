require 'rails_helper'

RSpec.describe SamlRequestValidator do
  describe '#call' do
    context 'valid authn context and sp and authorized nameID format' do
      it 'returns FormResponse with success: true' do
        sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
        authn_context = [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF]
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
          authn_context_comparison: 'exact',
        }

        response = SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(response.to_h).to include(
          success: true,
          errors: {},
          **extra,
        )
      end
    end

    context 'valid authn context and invalid sp and authorized nameID format' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.find_by(issuer: 'foo')
        authn_context = [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF]
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        extra = {
          authn_context: authn_context,
          service_provider: sp&.issuer,
          nameid_format: name_id_format,
          authn_context_comparison: 'exact',
        }
        errors = {
          service_provider: [t('errors.messages.unauthorized_service_provider')],
        }

        response = SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(response.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'valid authn context and unauthorized nameid format' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
        authn_context = [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF]
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
          authn_context_comparison: 'exact',
        }
        errors = {
          nameid_format: [t('errors.messages.unauthorized_nameid_format')],
        }

        response = SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(response.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'valid authn context and authorized email nameid format for SP' do
      it 'returns FormResponse with success: true' do
        sp = ServiceProvider.find_by(issuer: 'https://rp1.serviceprovider.com/auth/saml/metadata')
        sp.update!(email_nameid_format_allowed: true)
        authn_context = [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF]
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
          authn_context_comparison: 'exact',
        }

        response = SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(response.to_h).to include(
          success: true,
          errors: {},
          **extra,
        )
      end

      it 'returns FormResponse with success: true for ial2 on ial:2 sp' do
        sp = ServiceProvider.find_by(issuer: 'https://rp1.serviceprovider.com/auth/saml/metadata')
        sp.update!(email_nameid_format_allowed: true)
        sp.ial = 2
        authn_context = [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF]
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
          authn_context_comparison: 'exact',
        }

        response = SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(response.to_h).to include(
          success: true,
          errors: {},
          **extra,
        )
      end
    end

    context 'unsupported authn context with step up and valid sp and nameID format' do
      it 'returns a FormResponse with success: true for Comparison=minimum' do
        Saml::Idp::Constants::PASSWORD_AUTHN_CONTEXT_CLASSREFS.each do |password_context|
          sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
          authn_context = [password_context]
          comparison = 'minimum'
          name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
          extra = {
            authn_context: authn_context,
            service_provider: sp.issuer,
            nameid_format: name_id_format,
            authn_context_comparison: 'minimum',
          }

          response = SamlRequestValidator.new.call(
            service_provider: sp,
            authn_context: authn_context,
            authn_context_comparison: comparison,
            nameid_format: name_id_format,
          )

          expect(response.to_h).to include(
            success: true,
            errors: {},
            **extra,
          )
        end
      end

      it 'returns a FormResponse with success: true for Comparison=better' do
        Saml::Idp::Constants::PASSWORD_AUTHN_CONTEXT_CLASSREFS.each do |password_context|
          sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
          authn_context = [password_context]
          comparison = 'better'
          name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
          extra = {
            authn_context: authn_context,
            service_provider: sp.issuer,
            nameid_format: name_id_format,
            authn_context_comparison: 'better',
          }

          response = SamlRequestValidator.new.call(
            service_provider: sp,
            authn_context: authn_context,
            authn_context_comparison: comparison,
            nameid_format: name_id_format,
          )

          expect(response.to_h).to include(
            success: true,
            errors: {},
            **extra,
          )
        end
      end
    end

    context 'unsupported authn context without step up and valid sp and nameID format' do
      it 'returns FormResponse with success: false for unknown authn context' do
        Saml::Idp::Constants::PASSWORD_AUTHN_CONTEXT_CLASSREFS.each do |password_context|
          sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
          authn_context = [password_context]
          name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
          extra = {
            authn_context: authn_context,
            service_provider: sp.issuer,
            nameid_format: name_id_format,
            authn_context_comparison: 'exact',
          }
          errors = {
            authn_context: [t('errors.messages.unauthorized_authn_context')],
          }

          response = SamlRequestValidator.new.call(
            service_provider: sp,
            authn_context: authn_context,
            nameid_format: name_id_format,
          )

          expect(response.to_h).to include(
            success: false,
            errors: errors,
            error_details: hash_including(*errors.keys),
            **extra,
          )
        end
      end
    end

    context 'invalid authn context and valid sp and authorized nameID format' do
      it 'returns FormResponse with success: false for unknown authn context' do
        sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
        authn_context = ['IAL1']
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
          authn_context_comparison: 'exact',
        }
        errors = {
          authn_context: [t('errors.messages.unauthorized_authn_context')],
        }

        response = SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(response.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end

      it 'returns FormResponse with success: false for ial2 on an ial:1 sp' do
        sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
        sp.ial = 1
        authn_context = [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF]
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
          authn_context_comparison: 'exact',
        }
        errors = {
          authn_context: [t('errors.messages.unauthorized_authn_context')],
        }

        response = SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(response.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'invalid authn context and invalid sp and authorized nameID format' do
      it 'returns FormResponse with success: false' do
        sp = ServiceProvider.find_by(issuer: 'foo')
        authn_context = ['IAL1']
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
        extra = {
          authn_context: authn_context,
          service_provider: sp&.issuer,
          nameid_format: name_id_format,
          authn_context_comparison: 'exact',
        }
        errors = {
          authn_context: [t('errors.messages.unauthorized_authn_context')],
          service_provider: [t('errors.messages.unauthorized_service_provider')],
        }

        response = SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(response.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'valid authn context and sp and unauthorized nameID format' do
      it 'returns FormResponse with success: false with unauthorized nameid format' do
        sp = ServiceProvider.find_by(issuer: 'http://localhost:3000')
        authn_context = [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF]
        name_id_format = Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        extra = {
          authn_context: authn_context,
          service_provider: sp.issuer,
          nameid_format: name_id_format,
          authn_context_comparison: 'exact',
        }
        errors = {
          nameid_format: [t('errors.messages.unauthorized_nameid_format')],
        }

        response = SamlRequestValidator.new.call(
          service_provider: sp,
          authn_context: authn_context,
          nameid_format: name_id_format,
        )

        expect(response.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end
  end
end
