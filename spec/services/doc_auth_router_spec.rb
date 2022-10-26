require 'rails_helper'

RSpec.describe DocAuthRouter do
  describe '.client' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(doc_auth_vendor)
    end

    context 'for acuant' do
      let(:doc_auth_vendor) { Idp::Constants::Vendors::ACUANT }

      it 'is a translation-proxied acuant client' do
        expect(DocAuthRouter.client).to be_a(DocAuthRouter::DocAuthErrorTranslatorProxy)
        expect(DocAuthRouter.client.client).to be_a(DocAuth::Acuant::AcuantClient)
      end
    end

    context 'for lexisnexis' do
      let(:doc_auth_vendor) { Idp::Constants::Vendors::LEXIS_NEXIS }

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
  end

  describe '.doc_auth_vendor' do
    def reload_ab_test_initializer!
      # undefine the AB tests instances so we can re-initialize them with different config values
      AbTests.constants.each do |const_name|
        AbTests.class_eval { remove_const(const_name) }
      end
      load Rails.root.join('config', 'initializers', 'ab_tests.rb').to_s
    end

    let(:doc_auth_vendor) { 'test1' }
    let(:doc_auth_vendor_randomize_alternate_vendor) { 'test2' }
    let(:discriminator) { SecureRandom.uuid }
    let(:analytics) { FakeAnalytics.new }
    let(:doc_auth_vendor_randomize_percent) { 57 }
    let(:doc_auth_vendor_randomize) { true }

    before do
      allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(doc_auth_vendor)
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_alternate_vendor).
        and_return(doc_auth_vendor_randomize_alternate_vendor)

      allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent).
        and_return(doc_auth_vendor_randomize_percent)
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize).
        and_return(doc_auth_vendor_randomize)

      reload_ab_test_initializer!
    end

    after do
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize_percent).
        and_call_original
      allow(IdentityConfig.store).to receive(:doc_auth_vendor_randomize).
        and_call_original

      reload_ab_test_initializer!
    end

    context 'with a nil discriminator' do
      let(:discriminator) { nil }

      it 'is the default vendor, and logs analytics events' do
        expect(analytics).to receive(:idv_doc_auth_randomizer_defaulted)

        result = DocAuthRouter.doc_auth_vendor(discriminator: discriminator, analytics: analytics)

        expect(result).to eq(doc_auth_vendor)
      end
    end

    context 'with a discriminator that hashes inside the test group' do
      before do
        allow(AbTests::DOC_AUTH_VENDOR).
          to receive(:percent).with(discriminator).
          and_return(doc_auth_vendor_randomize_percent - 1)
      end

      it 'is the alternate vendor' do
        expect(DocAuthRouter.doc_auth_vendor(discriminator: discriminator)).
          to eq(doc_auth_vendor_randomize_alternate_vendor)
      end

      context 'with randomize false' do
        let(:doc_auth_vendor_randomize) { false }

        it 'is the original vendor' do
          expect(DocAuthRouter.doc_auth_vendor(discriminator: discriminator)).
            to eq(doc_auth_vendor)
        end
      end
    end

    context 'with a discriminator that hashes outside the test group' do
      before do
        allow(AbTests::DOC_AUTH_VENDOR).
          to receive(:percent).with(discriminator).
          and_return(doc_auth_vendor_randomize_percent + 1)
      end

      it 'is the original' do
        expect(DocAuthRouter.doc_auth_vendor(discriminator: discriminator)).
          to eq(doc_auth_vendor)
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
        proxy.get_results(instance_id: 'abcdef')
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

      response = proxy.get_results(instance_id: 'abcdef')

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

      response = proxy.get_results(instance_id: 'abcdef')

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
            general: [DocAuth::Errors::GENERAL_ERROR],
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
