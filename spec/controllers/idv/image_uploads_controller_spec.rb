require 'rails_helper'

describe Idv::ImageUploadsController do
  describe '#create' do
    let(:image_data) { 'data:image/png;base64,AAA' }
    let(:bad_image_data) { 'http://bad.com' }

    before do
      sign_in_as_user
    end

    subject(:action) { post :create, params: params, format: :json }

    let(:params) do
      {
        front: image_data,
        back: image_data,
        selfie: image_data,
      }
    end

    context 'when fields are missing' do
      before { params.delete(:front) }

      it 'returns error status when not provided image fields' do
        action

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to eq(false)
        expect(json[:errors]).to eq(['Front Please fill in this field.'])
      end
    end

    context 'with a bad image URL' do
      before { params.merge!(front: bad_image_data) }

      context 'with a locale param' do
        before { params.merge!(locale: 'es') }

        it 'translates errors using the locale param' do
          action

          json = JSON.parse(response.body, symbolize_names: true)
          expect(json[:errors]).to eq([
            "Frente #{I18n.t('doc_auth.errors.invalid_image_url', locale: 'es')}",
          ])
        end
      end
    end

    context 'when image upload succeeds' do
      it 'returns a successful response and modifies the session' do
        pending 'modifying the session'

        action

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to eq(true)

        expect(subject.user_session['idv/doc_auth']).to include('api_upload')
      end
    end

    context 'when image upload fails' do
      before do
        DocAuthMock::DocAuthMockClient.mock_response!(
          method: :post_images,
          response: DocAuthClient::Response.new(
            success: false,
            errors: ['Too blurry', 'Wrong document'],
          )
        )
      end

      it 'returns an error response' do
        post :create, params: {
          front: image_data,
          back: image_data,
          selfie: image_data,
        }, format: :json

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to eq(false)
        expect(json[:errors]).to eq(['Too blurry', 'Wrong document'])
      end
    end
  end
end
