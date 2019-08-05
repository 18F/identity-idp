require 'rails_helper'

describe Idv::JurisdictionController do
  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_attempts_allowed,
        :confirm_idv_needed,
      )
    end
  end

  before do
    stub_sign_in
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  let(:supported_jurisdiction) { 'WA' }
  let(:unsupported_jurisdiction) { 'CA' }

  describe '#new' do
    it 'tracks analytics' do
      get :new
      expect(@analytics).to have_received(:track_event).with(
        Analytics::IDV_JURISDICTION_VISIT,
      )
    end

    it 'renders the `new` template' do
      get :new
      expect(response).to render_template :new
    end
  end

  describe '#create' do
    it 'tracks analytics' do
      result = { success: true, errors: {} }

      post(
        :create,
        params: {
          jurisdiction: { state: supported_jurisdiction, ial2_consent_given: true },
        },
      )

      expect(@analytics).to have_received(:track_event).with(
        Analytics::IDV_JURISDICTION_FORM, result
      )
    end

    it 'puts the jurisdiction into the user session' do
      post(
        :create,
        params: {
          jurisdiction: { state: supported_jurisdiction, ial2_consent_given: true },
        },
      )

      expect(controller.user_session[:idv][:selected_jurisdiction]).to eq(supported_jurisdiction)
    end

    context 'with an unsupported jurisdiction' do
      it 'redirects to the unsupported jurisdiction fail page' do
        post(
          :create,
          params: {
            jurisdiction: { state: unsupported_jurisdiction, ial2_consent_given: true },
          },
        )

        expect(response).to redirect_to(idv_jurisdiction_failure_url(:unsupported_jurisdiction))
      end
    end

    context 'when the form is valid' do
      it 'redirects to the profile page' do
        post(
          :create,
          params: {
            jurisdiction: { state: supported_jurisdiction, ial2_consent_given: true },
          },
        )

        expect(response).to redirect_to(idv_session_url)
      end
    end
  end

  describe '#failure' do
    let(:reason) { 'unsupported_jurisdiction' }

    before do
      controller.user_session[:idv] = { selected_jurisdiction: supported_jurisdiction }
    end

    it 'renders the `_failure` template' do
      get :failure, params: { reason: reason }

      expect(response).to render_template('shared/_failure')
    end
  end
end
