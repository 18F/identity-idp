require 'rails_helper'

RSpec.describe SamlRequestValidator do
  describe '#call' do
    let(:issuer) { 'http://localhost:3000' }
    let(:sp) { ServiceProvider.find_by(issuer:) }
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

    let(:use_vot_in_sp_requests) { true }

    before do
      allow(IdentityConfig.store).to receive(
        :use_vot_in_sp_requests,
      ).and_return(
        use_vot_in_sp_requests,
      )
    end

    context 'valid authn context and sp and authorized nameID format' do
      [
        Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
      ].each do |ial_value|
        let(:authn_context) { [ial_value] }
        it 'returns FormResponse with success: true' do
          expect(response.to_h).to include(
            success: true,
            errors: {},
            **extra,
          )
        end
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

    context 'no authn context and valid sp and authorized nameID format' do
      let(:authn_context) { [] }
      it 'returns FormResponse with success: true' do
        expect(response.to_h).to include(
          success: true,
          errors: {},
          **extra,
        )
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

    context 'unknown context and valid sp and authorized nameID format' do
      context 'only the unknown authn_context is requested' do
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

        context 'unknown authn_context requested along with a valid one' do
          let(:authn_context) { ['IAL1', Saml::Idp::Constants::IAL_AUTH_ONLY_ACR] }

          it 'returns FormResponse with success: true' do
            expect(response.to_h).to include(
              success: true,
              errors: {},
              **extra,
            )
          end
        end
      end

      context 'authn context is ial2 when sp is ial 1' do
        [
          Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
          Saml::Idp::Constants::IAL_VERIFIED_ACR,
        ].each do |ial_value|
          let(:authn_context) { [ial_value] }

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

      shared_examples 'allows facial match IAL only if sp is authorized' do |facial_match_ial|
        let(:authn_context) { [facial_match_ial] }

        context "when the IAL requested is #{facial_match_ial}" do
          context 'when the service provider is allowed to use facial match ials' do
            before do
              sp.update(ial: 2)
              allow_any_instance_of(ServiceProvider).to receive(:facial_match_ial_allowed?).
                and_return(true)
            end

            it 'returns a successful response' do
              expect(response.to_h).to include(
                success: true,
                errors: {},
                **extra,
              )
            end
          end

          context 'when the service provider is not allowed to use facial match ials' do
            before do
              allow_any_instance_of(ServiceProvider).to receive(:facial_match_ial_allowed?).
                and_return(false)
            end

            it 'fails with an unauthorized error' do
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
      end

      it_behaves_like 'allows facial match IAL only if sp is authorized',
                      Saml::Idp::Constants::IAL2_BIO_REQUIRED_AUTHN_CONTEXT_CLASSREF

      it_behaves_like 'allows facial match IAL only if sp is authorized',
                      Saml::Idp::Constants::IAL2_BIO_PREFERRED_AUTHN_CONTEXT_CLASSREF

      it_behaves_like 'allows facial match IAL only if sp is authorized',
                      Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_PREFERRED_ACR

      it_behaves_like 'allows facial match IAL only if sp is authorized',
                      Saml::Idp::Constants::IAL_VERIFIED_FACIAL_MATCH_REQUIRED_ACR

      shared_examples 'allows semantic IAL only if sp is authorized' do |semantic_ial|
        let(:authn_context) { [semantic_ial] }

        context "when the IAL requested is #{semantic_ial}" do
          context 'when the service provider is allowed to use semantic ials' do
            before do
              sp.update(ial: 2)
            end

            it 'returns a successful response' do
              expect(response.to_h).to include(
                success: true,
                errors: {},
                **extra,
              )
            end
          end
        end
      end

      it_behaves_like 'allows semantic IAL only if sp is authorized',
                      Saml::Idp::Constants::IAL_VERIFIED_ACR

      it_behaves_like 'allows semantic IAL only if sp is authorized',
                      Saml::Idp::Constants::IAL_AUTH_ONLY_ACR
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

    context 'valid VTR and valid SP' do
      let(:authn_context) { ['C1'] }

      it 'returns FormResponse with success true' do
        expect(response.to_h).to include(
          success: true,
          errors: {},
          **extra,
        )
      end
    end

    context 'valid VTR for identity proofing with authorized SP for identity proofing' do
      let(:authn_context) { ['C1.P1'] }

      before { sp.update!(ial: 2) }

      it 'returns FormResponse with success true' do
        expect(response.to_h).to include(
          success: true,
          errors: {},
          **extra,
        )
      end
    end

    context 'valid VTR for identity proofing with unauthorized SP for identity proofing' do
      let(:authn_context) { ['C1.P1'] }

      before { sp.update!(ial: 1) }

      it 'returns FormResponse with success false' do
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

    context 'multiple VTR for identity proofing with unauthorized SP for identity proofing' do
      let(:authn_context) { ['C1', 'C1.P1'] }

      before { sp.update!(ial: 1) }

      it 'returns FormResponse with success false' do
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

    context 'valid VTR but VTR is disallowed by config' do
      let(:use_vot_in_sp_requests) { false }
      let(:authn_context) { ['C1'] }

      it 'returns FormResponse with success false' do
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

    context 'unparsable VTR' do
      let(:authn_context) { ['Fa.Ke.Va.Lu.E0'] }

      it 'returns FormResponse with success false' do
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
end
