require 'rails_helper'

RSpec.describe SamlRequestValidator do
  describe '#call' do
    let(:sp) { ServiceProvider.find_by(issuer: 'http://localhost:3000') }
    let(:name_id_format) { Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT }
    let(:authn_context) { [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF] }
    let(:comparison) { 'exact' }
    let(:extra) do
      {
        authn_context: authn_context,
        service_provider: sp&.issuer,
        nameid_format: name_id_format,
        authn_context_comparison: comparison,
      }
    end

    let(:response) do
      SamlRequestValidator.new.call(
        service_provider: sp,
        authn_context: authn_context,
        nameid_format: name_id_format,
      )
    end

    context 'valid authn context and sp and authorized nameID format' do
      it 'returns FormResponse with success: true' do
        expect(response.to_h).to include(
          success: true,
          errors: {},
          **extra,
        )
      end

      context 'ialmax authncontext and ialmax provider' do
        let(:authn_context) { [Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF] }
        before do
          expect(IdentityConfig.store).to receive(:allowed_ialmax_providers) { [sp.issuer] }
        end

        it 'returns FormResponse with success: true' do
          expect(response.to_h).to include(
            success: true,
            errors: {},
            **extra,
          )
        end
      end
    end

    context 'valid authn context and invalid sp and authorized nameID format' do
      let(:sp) { ServiceProvider.find_by(issuer: 'foo') }
      it 'returns FormResponse with success: false' do
        errors = {
          service_provider: [t('errors.messages.unauthorized_service_provider')],
        }

        expect(response.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'valid authn context and unauthorized nameid format' do
      let(:name_id_format) { Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL }
      it 'returns FormResponse with success: false' do
        errors = {
          nameid_format: [t('errors.messages.unauthorized_nameid_format')],
        }

        expect(response.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'valid authn context and authorized email nameid format for SP' do
      let(:sp) { ServiceProvider.find_by(issuer: 'https://rp1.serviceprovider.com/auth/saml/metadata') }
      let(:name_id_format) { Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL }
      before { sp.update!(email_nameid_format_allowed: true) }
      it 'returns FormResponse with success: true' do
        expect(response.to_h).to include(
          success: true,
          errors: {},
          **extra,
        )
      end

      context 'ial2 authn context and ial2 sp' do
        let(:authn_context) { [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF] }
        before { sp.update!(ial: 2) }
        it 'returns FormResponse with success: true for ial2 on ial:2 sp' do
          expect(response.to_h).to include(
            success: true,
            errors: {},
            **extra,
          )
        end
      end
    end

    context 'unsupported authn context with step up and valid sp and nameID format' do
      Saml::Idp::Constants::PASSWORD_AUTHN_CONTEXT_CLASSREFS.each do |password_context|
        let(:authn_context) { [password_context] }
        let(:comparison) { 'minimum' }
        it 'returns a FormResponse with success: true for Comparison=minimum' do
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

      Saml::Idp::Constants::PASSWORD_AUTHN_CONTEXT_CLASSREFS.each do |password_context|
        let(:authn_context) { [password_context] }
        let(:comparison) { 'better' }
        it 'returns a FormResponse with success: true for Comparison=better' do
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
      Saml::Idp::Constants::PASSWORD_AUTHN_CONTEXT_CLASSREFS.each do |password_context|
        let(:authn_context) { [password_context] }
        it 'returns FormResponse with success: false for unknown authn context' do
          errors = {
            authn_context: [t('errors.messages.unauthorized_authn_context')],
          }

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
      context 'unknown auth context' do
        let(:authn_context) { ['IAL1'] }
        it 'returns FormResponse with success: false' do
          errors = {
            authn_context: [t('errors.messages.unauthorized_authn_context')],
          }

          expect(response.to_h).to include(
            success: false,
            errors: errors,
            error_details: hash_including(*errors.keys),
            **extra,
          )
        end
      end

      context 'authn context is ial2 when sp is ial 1' do
        let(:authn_context) { [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF] }

        it 'returns FormResponse with success: false' do
          errors = {
            authn_context: [t('errors.messages.unauthorized_authn_context')],
          }

          expect(response.to_h).to include(
            success: false,
            errors: errors,
            error_details: hash_including(*errors.keys),
            **extra,
          )
        end
      end

      context 'authn context is ialmax when sp is not included' do
        let(:authn_context) { [Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF] }

        it 'returns FormResponse with success: false' do
          errors = {
            authn_context: [t('errors.messages.unauthorized_authn_context')],
          }

          expect(response.to_h).to include(
            success: false,
            errors: errors,
            error_details: hash_including(*errors.keys),
            **extra,
          )
        end
      end
    end

    context 'invalid authn context and invalid sp and authorized nameID format' do
      let(:sp) { ServiceProvider.find_by(issuer: 'foo') }
      let(:authn_context) { ['IAL1'] }

      it 'returns FormResponse with success: false' do
        errors = {
          authn_context: [t('errors.messages.unauthorized_authn_context')],
          service_provider: [t('errors.messages.unauthorized_service_provider')],
        }

        expect(response.to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(*errors.keys),
          **extra,
        )
      end
    end

    context 'valid authn context and sp and unauthorized nameID format' do
      let(:name_id_format) { Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL }
      it 'returns FormResponse with success: false with unauthorized nameid format' do
        errors = {
          nameid_format: [t('errors.messages.unauthorized_nameid_format')],
        }

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
