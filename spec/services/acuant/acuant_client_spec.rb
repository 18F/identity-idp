require 'rails_helper'

describe Acuant::AcuantClient do
  describe '#create_document' do
    it 'sends a create document request' do
      url = URI.join(Figaro.env.acuant_assure_id_url, '/AssureIDService/Document/Instance')
      stub_request(:post, url).to_return(body: AcuantFixtures.create_document_response)

      result = subject.create_document

      expect(result.success?).to eq(true)
      expect(result.instance_id).to eq('this-is-a-test-instance-id') # instance ID from fixture
    end
  end

  describe '#post_front_image' do
    it 'sends an upload image request for the front image' do
      instance_id = 'this-is-a-test-instance-id'
      url = URI.join(
        Figaro.env.acuant_assure_id_url, "/AssureIDService/Document/#{instance_id}/Image"
      )
      stub_request(:post, url).with(query: { side: 0, light: 0 }).to_return(body: '', status: 201)

      result = subject.post_front_image(
        instance_id: instance_id,
        image: DocAuthImageFixtures.document_front_image,
      )

      expect(result.success?).to eq(true)
    end
  end

  describe '#post_back_image' do
    it 'sends an upload image request for the back image' do
      instance_id = 'this-is-a-test-instance-id'
      url = URI.join(
        Figaro.env.acuant_assure_id_url, "/AssureIDService/Document/#{instance_id}/Image"
      )
      stub_request(:post, url).with(query: { side: 1, light: 0 }).to_return(body: '', status: 201)

      result = subject.post_back_image(
        instance_id: instance_id,
        image: DocAuthImageFixtures.document_back_image,
      )

      expect(result.success?).to eq(true)
    end
  end

  describe '#get_results' do
    context 'when the result is a pass' do
      it 'sends a request to get the results and returns success' do
        instance_id = 'this-is-a-test-instance-id'
        url = URI.join(Figaro.env.acuant_assure_id_url, "/AssureIDService/Document/#{instance_id}")
        stub_request(:get, url).to_return(body: AcuantFixtures.get_results_response_success)

        result = subject.get_results(instance_id: instance_id)

        expect(result.success?).to eq(true)
      end
    end

    context 'when the result is a failure' do
      it 'sends a request to get the results and returns failure' do
        instance_id = 'this-is-a-test-instance-id'
        url = URI.join(Figaro.env.acuant_assure_id_url, "/AssureIDService/Document/#{instance_id}")
        stub_request(:get, url).to_return(body: AcuantFixtures.get_results_response_failure)

        result = subject.get_results(instance_id: instance_id)

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
        'Acuant::Requests::CreateDocumentRequest Unexpected HTTP response 500',
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
