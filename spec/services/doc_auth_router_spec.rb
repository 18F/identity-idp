require 'rails_helper'

RSpec.describe DocAuthRouter do
  describe '.client' do
    context 'for lexisnexis' do
      subject do
        DocAuthRouter.client(vendor: 'lexisnexis')
      end
      it 'is a translation-proxied lexisnexis client' do
        expect(subject).to be_a(DocAuthRouter::DocAuthErrorTranslatorProxy)
        expect(subject.client).to be_a(DocAuth::LexisNexis::LexisNexisClient)
      end
    end

    context 'other config' do
      it 'errors' do
        expect { DocAuthRouter.client(vendor: 'unknown') }.to raise_error(RuntimeError)
      end
    end
  end

  describe DocAuthRouter::DocAuthErrorTranslatorProxy do
    subject(:proxy) do
      DocAuthRouter::DocAuthErrorTranslatorProxy.new(DocAuth::Mock::DocAuthMockClient.new)
    end

    it 'translates errors using the normal doc auth translator' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: DocAuth::Response.new(
          success: false,
          errors: {
            some_other_key: ['will not be translated'],
            general: [
              DocAuth::Errors::BARCODE_READ_CHECK,
              'Some unknown error that will be the generic message',
            ],
          },
        ),
      )

      response = I18n.with_locale(:es) do
        proxy.get_results
      end

      expect(response.errors[:some_other_key]).to eq(['will not be translated'])
      expect(response.errors[:general]).to match_array(
        [
          I18n.t('doc_auth.errors.general.no_liveness', locale: :es),
          I18n.t('doc_auth.errors.alerts.barcode_read_check', locale: :es),
        ],
      )
    end

    it 'translates generic network errors' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: DocAuth::Response.new(
          success: false,
          errors: {
            network: true,
          },
        ),
      )

      response = proxy.get_results

      expect(response.errors[:network]).to eq(I18n.t('doc_auth.errors.general.network_error'))
    end

    it 'translates generic network errors' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_images,
        response: DocAuth::Response.new(
          success: false,
          errors: {
            network: true,
          },
        ),
      )

      response = proxy.post_images(front_image: 'a', back_image: 'b')

      expect(response.errors[:network]).to eq(I18n.t('doc_auth.errors.general.network_error'))
    end

    it 'translates individual error keys errors' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_images,
        response: DocAuth::Response.new(
          success: false,
          errors: {
            id: [DocAuth::Errors::EXPIRATION_CHECKS],
            front: [DocAuth::Errors::VISIBLE_PHOTO_CHECK],
            back: [DocAuth::Errors::REF_CONTROL_NUMBER_CHECK],
            general: [DocAuth::Errors::GENERAL_ERROR],
            not_translated: true,
          },
        ),
      )

      response = proxy.post_images(front_image: 'a', back_image: 'b')

      expect(response.errors).to eq(
        id: [I18n.t('doc_auth.errors.alerts.expiration_checks')],
        front: [I18n.t('doc_auth.errors.alerts.visible_photo_check')],
        back: [I18n.t('doc_auth.errors.alerts.ref_control_number_check')],
        general: [I18n.t('doc_auth.errors.general.no_liveness')],
        not_translated: true,
      )
    end

    it 'logs a warning for errors it does not recognize and returns a generic error' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_images,
        response: DocAuth::Response.new(
          success: false,
          errors: {
            id: ['some_obscure_error'],
          },
        ),
      )

      expect(Rails.logger).to receive(:warn).with('unknown DocAuth error=some_obscure_error')

      response = proxy.post_images(front_image: 'a', back_image: 'b')

      expect(response.errors).to eq(
        id: [I18n.t('doc_auth.errors.general.no_liveness')],
      )
    end

    context 'translates http response errors and maintains exceptions' do
      it 'translate general message' do
        DocAuth::Mock::DocAuthMockClient.mock_response!(
          method: :post_images,
          response: DocAuth::Response.new(
            success: false,
            errors: {
              general: [DocAuth::Errors::IMAGE_LOAD_FAILURE],
            },
            exception: DocAuth::RequestError.new('Test 438 HTTP failure', 438),
          ),
        )

        response = proxy.post_images(front_image: 'a', back_image: 'b')
        expect(response.errors).to eq(general: [I18n.t('doc_auth.errors.http.image_load.top_msg')])
        expect(response.exception.message).to eq('Test 438 HTTP failure')
      end
      it 'translate related inline error messages for both sides' do
        DocAuth::Mock::DocAuthMockClient.mock_response!(
          method: :post_images,
          response: DocAuth::Response.new(
            success: false,
            errors: {
              general: [DocAuth::Errors::IMAGE_SIZE_FAILURE],
              front: [DocAuth::Errors::IMAGE_SIZE_FAILURE_FIELD],
              back: [DocAuth::Errors::IMAGE_SIZE_FAILURE_FIELD],
            },
            exception: DocAuth::RequestError.new('Test 440 HTTP failure', 440),
          ),
        )

        response = proxy.post_images(front_image: 'a', back_image: 'b')

        expect(response.errors).to eq(
          general: [I18n.t('doc_auth.errors.http.image_size.top_msg')],
          front: [I18n.t('doc_auth.errors.http.image_size.failed_short')],
          back: [I18n.t('doc_auth.errors.http.image_size.failed_short')],
        )
        expect(response.exception.message).to eq('Test 440 HTTP failure')
      end
      it 'translate related side specific inline error message' do
        DocAuth::Mock::DocAuthMockClient.mock_response!(
          method: :post_images,
          response: DocAuth::Response.new(
            success: false,
            errors: {
              general: [DocAuth::Errors::PIXEL_DEPTH_FAILURE],
              front: [DocAuth::Errors::PIXEL_DEPTH_FAILURE_FIELD],
            },
            exception: DocAuth::RequestError.new('Test 439 HTTP failure', 439),
          ),
        )

        response = proxy.post_images(front_image: 'a', back_image: 'b')

        expect(response.errors).to eq(
          general: [I18n.t('doc_auth.errors.http.pixel_depth.top_msg')],
          front: [I18n.t('doc_auth.errors.http.pixel_depth.failed_short')],
        )
        expect(response.exception.message).to eq('Test 439 HTTP failure')
      end
    end

    it 'translates doc type error' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_images,
        response: DocAuth::Response.new(
          success: false,
          errors: {
            general: [DocAuth::Errors::DOC_TYPE_CHECK],
            front: [DocAuth::Errors::CARD_TYPE],
            back: [DocAuth::Errors::CARD_TYPE],
          },
        ),
      )
      allow(I18n).to receive(:t).and_call_original
      allow(I18n).to receive(:t).with('doc_auth.errors.doc.doc_type_check').and_return(
        I18n.t('doc_auth.errors.doc.doc_type_check', attempt: 2),
      )
      response = proxy.post_images(front_image: 'a', back_image: 'b')
      expect(response.errors).to eq(
        front: [I18n.t('doc_auth.errors.general.fallback_field_level')],
        back: [I18n.t('doc_auth.errors.general.fallback_field_level')],
        general: [I18n.t(
          'doc_auth.errors.doc.doc_type_check', attempt: 2
        )],
      )
    end
  end
end
