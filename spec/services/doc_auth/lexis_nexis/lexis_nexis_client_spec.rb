require 'rails_helper'

describe DocAuth::LexisNexis::LexisNexisClient do
  let(:instance_id) { 'this-is-a-test-instance-id' }

  describe '#create_document' do
    it 'raises a NotImplemented error' do
      expect { subject.create_document }.to raise_error(NotImplementedError)
    end
  end

  describe '#post_front_image' do
    it 'raises a NotImplemented error' do
      expect do
        subject.post_front_image(
          instance_id: instance_id,
          image: DocAuthImageFixtures.document_front_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_back_image' do
    it 'raises a NotImplemented error' do
      expect do
        subject.post_back_image(
          instance_id: instance_id,
          image: DocAuthImageFixtures.document_back_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_selfie' do
    it 'raises a NotImplemented error' do
      expect do
        subject.post_selfie(
          instance_id: instance_id,
          image: DocAuthImageFixtures.selfie_image,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#get_results' do
    it 'raises a NotImplemented error' do
      expect do
        subject.get_results(
          instance_id: instance_id,
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#post_images' do
    let(:liveness_enabled) { false }
    let(:instance_id) { 'this-is-a-test-instance-id' }
    let(:image_upload_url) do
      URI.join(
        Figaro.env.lexisnexis_base_url,
        '/restws/identity/v2/test_account/customers.gsa.instant.verify.workflow/conversation'
      )
    end

    context 'with liveness checking enabled' do
      let(:liveness_enabled) { true }

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
      it 'sends an upload image request for the front and back DL images' do
        result = subject.post_images(
          front_image: DocAuthImageFixtures.document_front_image,
          back_image: DocAuthImageFixtures.document_back_image,
          selfie_image: DocAuthImageFixtures.selfie_image,
          liveness_checking_enabled: liveness_enabled,
        )

        expect(result.success?).to eq(true)
        expect(result.class).to eq(DocAuth::Response)
      end
    end

    context 'when the results return failure' do
      it 'returns a FormResponse with failure' do
        stub_request(:post, image_upload_url).to_return(body: LexisNexisFixtures.get_results_response_failure)

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
      url = URI.join(Figaro.env.acuant_assure_id_url, '/AssureIDService/Document/Instance')
      stub_request(:post, url).to_return(body: '', status: 500)

      result = subject.create_document

      expect(result.success?).to eq(false)
      expect(result.errors).to eq([I18n.t('errors.doc_auth.acuant_network_error')])
      expect(result.exception.message).to eq(
        'DocAuth::LexisNexis::Requests::CreateDocumentRequest Unexpected HTTP response 500',
      )
    end
  end

  context 'when there is a networking error' do
    it 'returns a response with an exception' do
      url = URI.join(Figaro.env.acuant_assure_id_url, '/AssureIDService/Document/Instance')
      stub_request(:post, url).to_raise(Faraday::TimeoutError.new('Connection failed'))

      result = subject.create_document

      expect(result.success?).to eq(false)
      expect(result.errors).to eq([I18n.t('errors.doc_auth.acuant_network_error')])
      expect(result.exception.message).to eq(
        'Connection failed',
      )
    end
  end
end
