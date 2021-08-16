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
        expect(DocAuthRouter.client.client).to be_a(DocAuth::Acuant::AcuantClient)
      end
    end

    context 'for lexisnexis' do
      let(:doc_auth_vendor) { 'lexisnexis' }

      it 'is a translation-proxied lexisnexis client' do
        expect(DocAuthRouter.client).to be_a(DocAuthRouter::DocAuthErrorTranslatorProxy)
        expect(DocAuthRouter.client.client).to be_a(DocAuth::LexisNexis::LexisNexisClient)
      end
    end

    context 'other config' do
      let(:doc_auth_vendor) { 'unknown' }

      it 'errors' do
        expect { DocAuthRouter.client }.to raise_error(RuntimeError)
      end
    end

    context 'for randomize config' do
      let(:doc_auth_vendor) { 'test1' }
      let(:doc_auth_vendor_randomize) { true }
      let(:doc_auth_vendor_randomize_vendor) { 'test2' }
      let(:iterations) { 500 }
      let(:percent_variance) { 0.035 } # 3.5% variance in randomness

      before(:each) do
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize).and_return(doc_auth_vendor_randomize)
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_vendor).and_return(doc_auth_vendor_randomize_vendor)
      end

      it 'doc_auth_vendor randomizes at a high number' do
        doc_auth_vendor_randomize_percent = 75
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent).and_return(doc_auth_vendor_randomize_percent)

        results = []
        (1..iterations).each { |_i| results.push(DocAuthRouter.doc_auth_vendor) }

        target_value = iterations*(doc_auth_vendor_randomize_percent.to_f/100)

        expect(results.tally['test2']).to be_within(iterations*percent_variance).of(target_value)
      end

      it 'doc_auth_vendor randomizes at a very high number' do
        doc_auth_vendor_randomize_percent = 97
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent).and_return(doc_auth_vendor_randomize_percent)

        results = []
        (1..iterations).each { |_i| results.push(DocAuthRouter.doc_auth_vendor) }

        target_value = iterations*(doc_auth_vendor_randomize_percent.to_f/100)

        expect(results.tally['test2']).to be_within(iterations*percent_variance).of(target_value)
      end

      it 'doc_auth_vendor randomizes at a low number' do
        doc_auth_vendor_randomize_percent = 15
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent)
          .and_return(doc_auth_vendor_randomize_percent)

        results = []
        (1..iterations).each { |_i| results.push(DocAuthRouter.doc_auth_vendor) }

        target_value = iterations*(doc_auth_vendor_randomize_percent.to_f/100)

        expect(results.tally['test2']).to be_within(iterations*percent_variance).of(target_value)
      end

      it 'doc_auth_vendor randomizes at a very low number' do
        doc_auth_vendor_randomize_percent = 4
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent)
          .and_return(doc_auth_vendor_randomize_percent)

        results = []
        (1..iterations).each { |_i| results.push(DocAuthRouter.doc_auth_vendor) }

        target_value = iterations*(doc_auth_vendor_randomize_percent.to_f/100)

        expect(results.tally['test2']).to be_within(iterations*percent_variance).of(target_value)
      end

      it 'doc_auth_vendor randomizes at 100 when set above 100' do
        doc_auth_vendor_randomize_percent = 105
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent)
          .and_return(doc_auth_vendor_randomize_percent)

        results = []
        (1..iterations).each { |_i| results.push(DocAuthRouter.doc_auth_vendor) }

        expect(results.tally['test2']).to be(iterations)
      end

      it 'doc_auth_vendor randomizes at 0 when set below 0' do
        doc_auth_vendor_randomize_percent = -5
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent)
          .and_return(doc_auth_vendor_randomize_percent)

        results = []
        (1..iterations).each { |_i| results.push(DocAuthRouter.doc_auth_vendor) }

        expect(results.tally['test2']).to be(nil)
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
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: DocAuth::Response.new(
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
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :get_results,
        response: DocAuth::Response.new(
          success: false,
          errors: {
            selfie: [DocAuth::Errors::SELFIE_FAILURE],
          },
        ),
      )

      response = proxy.get_results(instance_id: 'abcdef', liveness_enabled: false)

      expect(response.errors[:selfie]).to eq([I18n.t('doc_auth.errors.alerts.selfie_failure')])
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

      response = proxy.post_images(front_image: 'a', back_image: 'b', selfie_image: 'c')

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
            selfie: [DocAuth::Errors::SELFIE_FAILURE],
            general: [DocAuth::Errors::GENERAL_ERROR_LIVENESS],
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

      response = proxy.post_images(front_image: 'a', back_image: 'b', selfie_image: 'c')

      expect(response.errors).to eq(
        id: [I18n.t('doc_auth.errors.general.no_liveness')],
      )
    end

    context 'when the errors include DOCUMENT_EXPIRED' do
      context 'when there are multiple errors' do
        before do
          DocAuth::Mock::DocAuthMockClient.mock_response!(
            method: :post_images,
            response: DocAuth::Response.new(
              success: false,
              errors: {
                id: [
                  DocAuth::Errors::EXPIRATION_CHECKS,
                  DocAuth::Errors::DOCUMENT_EXPIRED_CHECK,
                ],
                general: [DocAuth::Errors::GENERAL_ERROR_LIVENESS],
              },
            ),
          )
        end

        it 'sets extra[:document_expired]' do
          response = proxy.post_images(front_image: 'a', back_image: 'b', selfie_image: 'c')

          expect(response.extra[:document_expired]).to eq(true)
        end
      end
    end

    it 'translates http response errors and maintains exceptions' do
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

      response = proxy.post_images(front_image: 'a', back_image: 'b', selfie_image: 'c')

      expect(response.errors).to eq(general: [I18n.t('doc_auth.errors.http.image_load')])
      expect(response.exception.message).to eq('Test 438 HTTP failure')
    end
  end
end
