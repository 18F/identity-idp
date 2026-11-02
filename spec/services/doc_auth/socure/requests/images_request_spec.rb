require 'rails_helper'

RSpec.describe DocAuth::Socure::Requests::ImagesRequest do
  let(:reference_id) { 'fake_reference_id' }
  let(:images_request_endpoint) do
    URI.join(
      IdentityConfig.store.socure_docv_images_request_endpoint,
      reference_id,
    ).to_s
  end
  let(:passport_book) { false }
  let(:image_types) { [:front, :back] }
  let(:user) { create(:user) }
  let(:analytics) { FakeAnalytics.new(user:) }

  subject(:images_request) do
    described_class.new(reference_id:, passport_book:, user:, image_types:)
  end
  let(:body) { DocAuthImageFixtures.zipped_files(reference_id:, passport: passport_book).to_s }
  let(:status) { 200 }
  let(:message) do
    [
      subject.class.name,
      'Unexpected HTTP response',
      status,
    ].join(' ')
  end

  let(:connection_error_attributes) do
    {
      success: false,
      errors: { network: true },
      exception: DocAuth::RequestError.new(message, status),
      extra: {
        vendor: 'Socure',
        vendor_status_code: nil,
        vendor_status_message: nil,
      }.compact,
    }
  end

  describe '#fetch' do
    before do
      allow(Analytics).to receive(:new).and_return(analytics)
      stub_request(:get, images_request_endpoint)
        .to_return(
          status:,
          body:,
        )
    end

    it 'fetches from the correct url' do
      subject.fetch

      expect(WebMock).to have_requested(:get, images_request_endpoint)
        .with(body: {})
    end

    context 'when mock Socure is enabled' do
      let(:mock_images_request_endpoint) do
        DocAuth::Mock::Socure.instance.images_endpoint(reference_id:)
      end

      before do
        allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return('mock_socure')
        stub_request(:get, mock_images_request_endpoint)
          .with(query: { types: image_types.map(&:to_s) })
          .to_return(
            status:,
            body:,
          )
      end

      it 'fetches from the mock endpoint with image types' do
        subject.fetch

        expect(WebMock).to have_requested(:get, mock_images_request_endpoint)
          .with(query: { types: image_types.map(&:to_s) })
      end
    end

    it 'creates an IdvImages object with the binary data' do
      response = subject.fetch

      expect(response.class).to eq(Idv::IdvImages)
      expect(response.images.first.value.class).to eq Idv::BinaryImage
      expect(response.images.map(&:type)).to contain_exactly(:back, :front)
    end

    it 'logs an analytics event' do
      subject.fetch

      expect(analytics).to have_logged_event(
        :idv_socure_images_requested,
        http_status: 200,
        user_id: user.uuid,
        reference_id:,
        image_types_present: [:front, :back],
        passport_book: false,
      )
    end

    context 'when analytics logging raises' do
      before do
        allow(analytics).to receive(:idv_socure_images_requested).and_raise('boom')
      end

      it 'still returns the images and notifies NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error).with(instance_of(RuntimeError))

        expect(subject.fetch).to be_a(Idv::IdvImages)
      end
    end

    context 'when passport_book is true' do
      let(:passport_book) { true }
      let(:image_types) { [:passport] }

      it 'logs passport_book and the passport image type' do
        subject.fetch

        expect(analytics).to have_logged_event(
          :idv_socure_images_requested,
          http_status: 200,
          user_id: user.uuid,
          reference_id:,
          image_types_present: [:passport],
          passport_book: true,
        )
      end

      it 'creates an IdvImages object with the binary data including passport' do
        response = subject.fetch

        expect(response.class).to eq(Idv::IdvImages)
        expect(response.images.first.value.class).to eq Idv::BinaryImage
        expect(response.images.map(&:type)).to contain_exactly(:passport)
      end
    end

    context 'when the response is empty' do
      let(:body) { '' }

      it 'returns an error' do
        response = subject.fetch

        expect(response).to eq connection_error_attributes
      end
    end

    context 'we get a 403 back' do
      let(:status) { 403 }
      let(:body) { {}.to_json }

      it 'does not raise an exception' do
        expect { subject.fetch }.not_to raise_error
      end

      it 'logs the http status with no image types' do
        subject.fetch

        expect(analytics).to have_logged_event(
          :idv_socure_images_requested,
          http_status: 403,
          user_id: user.uuid,
          reference_id:,
          image_types_present: [],
          passport_book: false,
        )
      end
    end

    context 'we get a 500 back' do
      let(:status) { {} }
      let(:body) { {}.to_json }

      it 'does not raise an exception' do
        expect { subject.fetch }.not_to raise_error
      end
    end

    context 'we get a 400 back' do
      let(:status) { 400 }
      let(:body) do
        {
          'referenceId' => 'socure-reference-id',
          'msg' => {
            'status' => 400,
            'msg' => 'Images not available: Document type is not supported for verification.',
          },
        }.to_json
      end

      it 'does not raise an exception' do
        expect { subject.fetch }.not_to raise_error
      end
    end

    context 'with timeout exception' do
      let(:response) { nil }
      let(:response_status) { 403 }
      let(:faraday_connection_failed_exception) { Faraday::ConnectionFailed }

      before do
        stub_request(:get, images_request_endpoint).to_raise(faraday_connection_failed_exception)
      end
      it 'expect handle_connection_error method to be called' do
        result = subject.fetch
        expect(result[:success]).to eq(connection_error_attributes[:success])
        expect(result[:errors]).to eq(connection_error_attributes[:errors])
        expect(result[:exception]).to be_a Faraday::ConnectionFailed
        expect(result[:extra]).to eq(connection_error_attributes[:extra])
      end

      it 'logs the event without an http status' do
        subject.fetch

        expect(analytics).to have_logged_event(
          :idv_socure_images_requested,
          user_id: user.uuid,
          reference_id:,
          image_types_present: [],
          passport_book: false,
        )
      end
    end
  end
end
