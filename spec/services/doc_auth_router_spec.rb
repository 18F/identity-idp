require 'rails_helper'

RSpec.describe DocAuthRouter do
  describe '.client' do
    before do
      allow(AppConfig.env).to receive(:doc_auth_vendor).and_return(doc_auth_vendor)
      allow(AppConfig.env).to receive(:acuant_simulator).and_return(acuant_simulator)
    end

    context 'legacy mock configuration' do
      let(:doc_auth_vendor) { '' }
      let(:acuant_simulator) { 'true' }

      it 'is the mock client' do
        expect(DocAuthRouter.client).to be_a(IdentityDocAuth::Mock::DocAuthMockClient)
      end
    end

    context 'for acuant' do
      let(:doc_auth_vendor) { 'acuant' }
      let(:acuant_simulator) { '' }

      it 'is a translation-proxied acuant client' do
        expect(DocAuthRouter.client).to be_a(DocAuthRouter::AcuantErrorTranslatorProxy)
        expect(DocAuthRouter.client.client).to be_a(IdentityDocAuth::Acuant::AcuantClient)
      end
    end

    context 'for lexisnexis' do
      let(:doc_auth_vendor) { 'lexisnexis' }
      let(:acuant_simulator) { '' }

      it 'is a translation-proxied lexisnexis client' do
        expect(DocAuthRouter.client).to be_a(DocAuthRouter::LexisNexisTranslatorProxy)
        expect(DocAuthRouter.client.client).to be_a(IdentityDocAuth::LexisNexis::LexisNexisClient)
      end
    end

    context 'other config' do
      let(:doc_auth_vendor) { 'unknown' }
      let(:acuant_simulator) { '' }

      it 'errors' do
        expect { DocAuthRouter.client }.to raise_error(RuntimeError)
      end
    end
  end

  describe '.notify_exception' do
    let(:exception) { RuntimeError.new }

    it 'notifies NewRelic' do
      expect(NewRelic::Agent).to receive(:notice_error).with(exception)

      DocAuthRouter.notify_exception(exception)
    end

    context 'with custom params' do
      let(:params) { { count: 1 } }

      it 'forwards on custom_params to NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error).with(exception, custom_params: params)

        DocAuthRouter.notify_exception(exception, params)
      end
    end
  end

  describe DocAuthRouter::AcuantErrorTranslatorProxy do
    subject(:proxy) do
      DocAuthRouter::AcuantErrorTranslatorProxy.new(IdentityDocAuth::Mock::DocAuthMockClient.new)
    end

    it 'translates errors[:results] using FriendlyError' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: {
            some_other_key: ['will not be translated'],
            results: [
              'The 2D barcode could not be read',
              'Some unknown error that will be the generic message',
            ],
          },
        ),
      )

      response = I18n.with_locale(:es) { proxy.get_results(instance_id: 'abcdef') }

      expect(response.errors[:some_other_key]).to eq(['will not be translated'])
      expect(response.errors[:results]).to match_array(
        [
          I18n.t('errors.doc_auth.general_error', locale: :es),
          I18n.t('friendly_errors.doc_auth.barcode_could_not_be_read', locale: :es),
        ],
      )
    end

    it 'translates generic network errors' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: {
            network: true,
          },
        ),
      )

      response = proxy.get_results(instance_id: 'abcdef')

      expect(response.errors[:network]).to eq(I18n.t('errors.doc_auth.acuant_network_error'))
    end

    it 'translates generic selfie errors' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: {
            selfie: true,
          },
        ),
      )

      response = proxy.get_results(instance_id: 'abcdef')

      expect(response.errors[:selfie]).to eq(I18n.t('errors.doc_auth.selfie'))
    end
  end

  describe DocAuthRouter::LexisNexisTranslatorProxy do
    subject(:proxy) do
      DocAuthRouter::LexisNexisTranslatorProxy.new(IdentityDocAuth::Mock::DocAuthMockClient.new)
    end

    it 'translates generic network errors' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_images,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: {
            network: true,
          },
        ),
      )

      response = proxy.post_images(front_image: 'a', back_image: 'b', selfie_image: 'c')

      expect(response.errors[:network]).to eq(I18n.t('doc_auth.errors.lexis_nexis.network_error'))
    end

    it 'translates individual error keys errors' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_images,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: {
            id: [IdentityDocAuth::LexisNexis::Errors::EXPIRATION_CHECKS],
            front: [IdentityDocAuth::LexisNexis::Errors::VISIBLE_PHOTO_CHECK],
            back: [IdentityDocAuth::LexisNexis::Errors::REF_CONTROL_NUMBER_CHECK],
            selfie: [IdentityDocAuth::LexisNexis::Errors::SELFIE_FAILURE],
            general: [IdentityDocAuth::LexisNexis::Errors::GENERAL_ERROR_LIVENESS],
            not_translated: true,
          },
        ),
      )

      response = proxy.post_images(front_image: 'a', back_image: 'b', selfie_image: 'c')

      expect(response.errors).to eq(
        id: [I18n.t('doc_auth.errors.lexis_nexis.expiration_checks')],
        front: [I18n.t('doc_auth.errors.lexis_nexis.visible_photo_check')],
        back: [I18n.t('doc_auth.errors.lexis_nexis.ref_control_number_check')],
        selfie: [I18n.t('doc_auth.errors.lexis_nexis.selfie_failure')],
        general: [I18n.t('doc_auth.errors.lexis_nexis.general_error_liveness')],
        not_translated: true,
      )
    end

    it 'logs a warning for errors it does not recognize and returns a generic error' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_images,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: {
            id: ['some_obscure_error'],
          },
        ),
      )

      expect(Rails.logger).to receive(:warn).with('unknown LexisNexis error=some_obscure_error')

      response = proxy.post_images(front_image: 'a', back_image: 'b', selfie_image: 'c')

      expect(response.errors).to eq(
        id: [I18n.t('doc_auth.errors.lexis_nexis.general_error_no_liveness')],
      )
    end
  end
end
