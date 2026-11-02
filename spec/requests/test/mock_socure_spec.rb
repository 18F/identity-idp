# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Test::MockSocureController' do
  before do
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return('mock_socure')
  end

  describe 'GET /test/mock_socure/api/5.0/documents/:reference_id.zip' do
    let(:reference_id) { 'fake-reference-id' }
    let(:params) { { types: %w[front back] } }

    subject(:request_images) do
      get test_mock_socure_images_request_path(reference_id:, format: :zip), params:
    end
    context 'with no types' do
      let(:params) { {} }
      it 'returns front and back document images' do
        request_images

        expect(response).to have_http_status(:ok)
        expect(zip_entry_names(response.body)).to contain_exactly(
          'documentbackDoc_Back_1_blob.jpg',
          'documentfrontDoc_Front_1_blob.jpg',
        )
      end
    end

    context 'with back and front types' do
      it 'returns front and back document images' do
        request_images

        expect(response).to have_http_status(:ok)
        expect(zip_entry_names(response.body)).to contain_exactly(
          'documentbackDoc_Back_1_blob.jpg',
          'documentfrontDoc_Front_1_blob.jpg',
        )
      end

      context 'and a selfie type' do
        let(:params) { { types: %w[front back selfie] } }
        it 'returns front, back and selfie document images' do
          request_images

          expect(response).to have_http_status(:ok)
          expect(zip_entry_names(response.body)).to contain_exactly(
            'documentbackDoc_Back_1_blob.jpg',
            'documentfrontDoc_Front_1_blob.jpg',
            'Doc_Selfie_1_blob.jpg',
          )
        end
      end
    end

    context 'with passport and selfie image types' do
      let(:params) { { types: %w[passport selfie] } }

      it 'returns passport and selfie images' do
        request_images

        expect(response).to have_http_status(:ok)
        expect(zip_entry_names(response.body)).to contain_exactly(
          'Doc_Selfie_1_blob.jpg',
          'documentfrontDoc_Front_1_blob.jpg',
        )
      end
    end
  end

  def zip_entry_names(body)
    Zip::File.open_buffer(body).entries.map(&:name)
  end
end
