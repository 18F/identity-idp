require 'rails_helper'

RSpec.describe DocAuthRouter do
  describe '.client' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(doc_auth_vendor)
    end

    context 'for acuant' do
      let(:doc_auth_vendor) { 'acuant' }

      it 'is a translation-proxied acuant client' do
        expect(DocAuthRouter.client).to be_a(DocAuthRouter::DocAuthErrorTranslatorProxy)
        expect(DocAuthRouter.client.client).to be_a(IdentityDocAuth::Acuant::AcuantClient)
      end
    end

    context 'for lexisnexis' do
      let(:doc_auth_vendor) { 'lexisnexis' }

      it 'is a translation-proxied lexisnexis client' do
        expect(DocAuthRouter.client).to be_a(DocAuthRouter::DocAuthErrorTranslatorProxy)
        expect(DocAuthRouter.client.client).to be_a(IdentityDocAuth::LexisNexis::LexisNexisClient)
      end
    end

    context 'other config' do
      let(:doc_auth_vendor) { 'unknown' }

      it 'errors' do
        expect { DocAuthRouter.client }.to raise_error(RuntimeError)
      end
    end
  end

  describe '.notify_exception' do
    let(:exception) { RuntimeError.new }

    it 'notifies NewRelic' do
      expect(NewRelic::Agent).to receive(:notice_error).with(exception, expected: false)

      DocAuthRouter.notify_exception(exception)
    end

    context 'with custom params' do
      let(:params) { { count: 1 } }

      it 'forwards on custom_params to NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error).with(
          exception,
          custom_params: params,
          expected: false,
        )

        DocAuthRouter.notify_exception(exception, params)
      end
    end
  end

  describe DocAuthRouter::DocAuthErrorTranslatorProxy do
    subject(:proxy) do
      DocAuthRouter::DocAuthErrorTranslatorProxy.new(IdentityDocAuth::Mock::DocAuthMockClient.new)
    end

    it 'translates errors[:results] using FriendlyError' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: {
            some_other_key: ['will not be translated'],
            general: [
              IdentityDocAuth::Errors::BARCODE_READ_CHECK,
              'Some unknown error that will be the generic message',
            ],
          },
        ),
      )

      response = I18n.with_locale(:es) {
        proxy.get_results(instance_id: 'abcdef', liveness_enabled: false)
      }

      expect(response.errors[:some_other_key]).to eq(['will not be translated'])
      expect(response.errors[:general]).to match_array(
        [
          I18n.t('doc_auth.errors.general.no_liveness', locale: :es),
          I18n.t('doc_auth.errors.alerts.barcode_read_check', locale: :es),
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

      response = proxy.get_results(instance_id: 'abcdef', liveness_enabled: false)

      expect(response.errors[:network]).to eq(I18n.t('doc_auth.errors.general.network_error'))
    end

    it 'translates generic selfie errors' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: {
            selfie: [IdentityDocAuth::Errors::SELFIE_FAILURE],
          },
        ),
      )

      response = proxy.get_results(instance_id: 'abcdef', liveness_enabled: false)

      expect(response.errors[:selfie]).to eq([I18n.t('doc_auth.errors.alerts.selfie_failure')])
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

      expect(response.errors[:network]).to eq(I18n.t('doc_auth.errors.general.network_error'))
    end

    it 'translates individual error keys errors' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_images,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: {
            id: [IdentityDocAuth::Errors::EXPIRATION_CHECKS],
            front: [IdentityDocAuth::Errors::VISIBLE_PHOTO_CHECK],
            back: [IdentityDocAuth::Errors::REF_CONTROL_NUMBER_CHECK],
            selfie: [IdentityDocAuth::Errors::SELFIE_FAILURE],
            general: [IdentityDocAuth::Errors::GENERAL_ERROR_LIVENESS],
            not_translated: true,
          },
        ),
      )

      response = proxy.post_images(front_image: 'a', back_image: 'b', selfie_image: 'c')

      expect(response.errors).to eq(
        id: [I18n.t('doc_auth.errors.alerts.expiration_checks')],
        front: [I18n.t('doc_auth.errors.alerts.visible_photo_check')],
        back: [I18n.t('doc_auth.errors.alerts.ref_control_number_check')],
        selfie: [I18n.t('doc_auth.errors.alerts.selfie_failure')],
        general: [I18n.t('doc_auth.errors.general.liveness')],
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

      expect(Rails.logger).to receive(:warn).with('unknown DocAuth error=some_obscure_error')

      response = proxy.post_images(front_image: 'a', back_image: 'b', selfie_image: 'c')

      expect(response.errors).to eq(
        id: [I18n.t('doc_auth.errors.general.no_liveness')],
      )
    end
  end
end
