require 'rails_helper'

RSpec.describe Api::Internal::TwoFactorAuthentication::WebauthnController do
  let(:user) { create(:user, :with_phone) }
  let(:configuration) { create(:webauthn_configuration, user:) }

  before do
    stub_analytics
    stub_sign_in(user) if user
  end

  describe '#update' do
    let(:name) { 'example' }
    let(:params) { { id: configuration.id, name: } }
    let(:response) { put :update, params: params }
    subject(:response_body) { JSON.parse(response.body, symbolize_names: true) }

    it 'responds with successful result' do
      expect(response_body).to eq(success: true)
      expect(response.status).to eq(200)
    end

    it 'logs the submission attempt' do
      response

      expect(@analytics).to have_logged_event(
        :webauthn_update_name_submitted,
        success: true,
        configuration_id: configuration.id.to_s,
        error_details: nil,
      )
    end

    it 'includes csrf token in the response headers' do
      expect(response.headers['X-CSRF-Token']).to be_kind_of(String)
    end

    context 'signed out' do
      let(:user) { nil }
      let(:configuration) { create(:webauthn_configuration) }

      it 'responds with unauthorized response' do
        expect(response_body).to eq(error: 'Unauthorized')
        expect(response.status).to eq(401)
      end
    end

    context 'with invalid submission' do
      let(:name) { '' }

      it 'responds with unsuccessful result' do
        expect(response_body).to eq(success: false, error: t('errors.messages.blank'))
        expect(response.status).to eq(400)
      end

      it 'logs the submission attempt' do
        response

        expect(@analytics).to have_logged_event(
          :webauthn_update_name_submitted,
          success: false,
          configuration_id: configuration.id.to_s,
          error_details: { name: { blank: true } },
        )
      end
    end

    context 'not recently authenticated' do
      before do
        allow(controller).to receive(:recently_authenticated_2fa?).and_return(false)
      end

      it 'responds with unauthorized response' do
        expect(response_body).to eq(error: 'Unauthorized')
        expect(response.status).to eq(401)
      end
    end

    context 'with a configuration that does not exist' do
      let(:params) { { id: 0 } }

      it 'responds with unsuccessful result' do
        expect(response_body).to eq(
          success: false,
          error: t('errors.manage_authenticator.internal_error'),
        )
        expect(response.status).to eq(400)
      end
    end

    context 'with a configuration that does not belong to the user' do
      let(:configuration) { create(:webauthn_configuration) }

      it 'responds with unsuccessful result' do
        expect(response_body).to eq(
          success: false,
          error: t('errors.manage_authenticator.internal_error'),
        )
        expect(response.status).to eq(400)
      end
    end
  end

  describe '#destroy' do
    let(:params) { { id: configuration.id } }
    let(:response) { delete :destroy, params: params }
    subject(:response_body) { JSON.parse(response.body, symbolize_names: true) }

    it 'responds with successful result' do
      expect(response_body).to eq(success: true)
      expect(response.status).to eq(200)
    end

    it 'logs the submission attempt' do
      response

      expect(@analytics).to have_logged_event(
        :webauthn_delete_submitted,
        success: true,
        configuration_id: configuration.id.to_s,
        error_details: nil,
      )
    end

    it 'includes csrf token in the response headers' do
      expect(response.headers['X-CSRF-Token']).to be_kind_of(String)
    end

    context 'signed out' do
      let(:user) { nil }
      let(:configuration) { create(:webauthn_configuration) }

      it 'responds with unauthorized response' do
        expect(response_body).to eq(error: 'Unauthorized')
        expect(response.status).to eq(401)
      end
    end

    context 'with invalid submission' do
      let(:user) { create(:user) }

      it 'responds with unsuccessful result' do
        expect(response_body).to eq(
          success: false,
          error: t('errors.manage_authenticator.remove_only_method_error'),
        )
        expect(response.status).to eq(400)
      end

      it 'logs the submission attempt' do
        response

        expect(@analytics).to have_logged_event(
          :webauthn_delete_submitted,
          success: false,
          configuration_id: configuration.id.to_s,
          error_details: { configuration_id: { only_method: true } },
        )
      end
    end

    context 'not recently authenticated' do
      before do
        allow(controller).to receive(:recently_authenticated_2fa?).and_return(false)
      end

      it 'responds with unauthorized response' do
        expect(response_body).to eq(error: 'Unauthorized')
        expect(response.status).to eq(401)
      end
    end

    context 'with a configuration that does not exist' do
      let(:params) { { id: 0 } }

      it 'responds with unsuccessful result' do
        expect(response_body).to eq(
          success: false,
          error: t('errors.manage_authenticator.internal_error'),
        )
        expect(response.status).to eq(400)
      end
    end

    context 'with a configuration that does not belong to the user' do
      let(:configuration) { create(:webauthn_configuration) }

      it 'responds with unsuccessful result' do
        expect(response_body).to eq(
          success: false,
          error: t('errors.manage_authenticator.internal_error'),
        )
        expect(response.status).to eq(400)
      end
    end
  end
end
