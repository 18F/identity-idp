require 'rails_helper'

describe DocAuth::LexisNexis::LexisNexisClient do
  let(:liveness_enabled) { true }
  let(:workflow) { Figaro.env.lexisnexis_trueid_liveness_workflow }
  let(:image_upload_url) do
    URI.join(
      Figaro.env.lexisnexis_base_url,
      "/restws/identity/v3/accounts/test_account/workflows/#{workflow}/conversations",
    )
  end

  describe '#create_document' do
    it 'raises a NotImplemented error' do
      expect { subject.create_document }.to raise_error(NotImplementedError)
    end
  end

  describe '#post_front_image' do
    it 'raises a NotImplemented error' do
      expect do
        subject.post_front_image(
          instance_id: 123,
          image: DocAuthImageFixtures.document_front_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_back_image' do
    it 'raises a NotImplemented error' do
      expect do
        subject.post_back_image(
          instance_id: 123,
          image: DocAuthImageFixtures.document_back_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_selfie' do
    it 'raises a NotImplemented error' do
      expect do
        subject.post_selfie(
          instance_id: 123,
          image: DocAuthImageFixtures.selfie_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#get_results' do
    it 'raises a NotImplemented error' do
      expect do
        subject.get_results(
          instance_id: 123,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_images' do
    before do
      stub_request(:post, image_upload_url).to_return(
        body: LexisNexisFixtures.true_id_response_success,
      )
    end

    context 'with liveness checking enabled' do
      let(:liveness_enabled) { true }
      let(:workflow) { Figaro.env.lexisnexis_trueid_liveness_workflow }

      it 'sends an upload image request for the front, back, and selfie images' do
        result = subject.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_enabled: liveness_enabled,
        )

        expect(result.success?).to eq(true)
        expect(result.pii_from_doc).to_not be_empty
      end
    end

    context 'with liveness checking disabled' do
      let(:liveness_enabled) { false }
      let(:workflow) { Figaro.env.lexisnexis_trueid_noliveness_workflow }

      it 'sends an upload image request for the front and back DL images' do
        result = subject.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: nil,
          liveness_checking_enabled: liveness_enabled,
        )

        expect(result.success?).to eq(true)
        expect(result.class).to eq(DocAuth::LexisNexis::Responses::TrueIdResponse)
      end
    end

    context 'when the results return failure' do
      it 'returns a FormResponse with failure' do
        stub_request(:post, image_upload_url).to_return(
          body: LexisNexisFixtures.true_id_response_failure,
        )

        result = subject.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_enabled: liveness_enabled,
        )

        expect(result.success?).to eq(false)
      end
    end
  end

  context 'when the request is not successful' do
    it 'returns a response with an exception' do
      stub_request(:post, image_upload_url).to_return(body: '', status: 500)

      result = subject.post_images(
        front_image: DocAuthImageFixtures.document_front_image,
        back_image: DocAuthImageFixtures.document_back_image,
        selfie_image: DocAuthImageFixtures.selfie_image,
        liveness_checking_enabled: liveness_enabled,
      )

      expect(result.success?).to eq(false)
      expect(result.errors).to eq({ network: I18n.t('doc_auth.errors.lexis_nexis.network_error') })
      expect(result.exception.message).to eq(
        'DocAuth::LexisNexis::Requests::TrueIdRequest Unexpected HTTP response 500',
      )
    end
  end

  context 'when there is a networking error' do
    it 'returns a response with an exception' do
      stub_request(:post, image_upload_url).to_raise(Faraday::TimeoutError.new('Connection failed'))

      result = subject.post_images(
        front_image: DocAuthImageFixtures.document_front_image,
        back_image: DocAuthImageFixtures.document_back_image,
        selfie_image: DocAuthImageFixtures.selfie_image,
        liveness_checking_enabled: liveness_enabled,
      )

      expect(result.success?).to eq(false)
      expect(result.errors).to eq({ network: I18n.t('doc_auth.errors.lexis_nexis.network_error') })
      expect(result.exception.message).to eq(
        'Connection failed',
      )
    end
  end
end
