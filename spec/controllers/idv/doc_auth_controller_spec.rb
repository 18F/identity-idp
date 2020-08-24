require 'rails_helper'

describe Idv::DocAuthController do
  include DocAuthHelper

  describe 'before_actions' do
    it 'includes corrects before_actions' do
      expect(subject).to have_actions(:before,
                                      :confirm_two_factor_authenticated,
                                      :fsm_initialize,
                                      :ensure_correct_step)
    end
  end

  before do |example|
    stub_sign_in unless example.metadata[:skip_sign_in]
    stub_analytics
    allow(@analytics).to receive(:track_event)
  end

  describe 'unauthenticated', :skip_sign_in do
    it 'redirects to the root url' do
      get :index

      expect(response).to redirect_to root_url
    end
  end

  describe '#index' do
    it 'redirects to the first step' do
      get :index

      expect(response).to redirect_to idv_doc_auth_step_url(step: :welcome)
    end
  end

  describe '#show' do
    it 'renders the front_image template' do
      mock_next_step(:ssn)
      get :show, params: { step: 'ssn' }

      expect(response).to render_template :ssn
    end

    it 'renders the front_image template' do
      mock_next_step(:front_image)
      get :show, params: { step: 'front_image' }

      expect(response).to render_template :front_image
    end

    it 'renders the back_image template' do
      mock_next_step(:back_image)
      get :show, params: { step: 'back_image' }

      expect(response).to render_template :back_image
    end

    it 'redirect to the right step' do
      mock_next_step(:front_image)
      get :show, params: { step: 'back_image' }

      expect(response).to redirect_to idv_doc_auth_step_url(:front_image)
    end

    it 'renders a 404 with a non existent step' do
      get :show, params: { step: 'foo' }

      expect(response).to_not be_not_found
    end

    it 'tracks analytics' do
      result = { step: 'welcome' }

      get :show, params: { step: 'welcome' }

      expect(@analytics).to have_received(:track_event).with(
        Analytics::DOC_AUTH + ' visited', result
      )
    end

    it 'add unsafe-eval to the CSP for capture steps' do
      capture_steps = %i[
        front_image
        back_image
        mobile_front_image
        mobile_back_image
        selfie
        document_capture
      ]
      capture_steps.each do |step|
        mock_next_step(step)

        get :show, params: { step: step }

        script_src = response.request.headers.env['secure_headers_request_config'].csp.script_src
        expect(script_src).to include("'unsafe-eval'")
      end
    end

    it 'does not add unsafe-eval to the CSP for non-capture steps' do
      mock_next_step(:ssn)

      get :show, params: { step: 'ssn' }

      secure_header_config = response.request.headers.env['secure_headers_request_config']
      expect(secure_header_config).to be_nil
    end
  end

  describe '#update' do
    it 'tracks analytics' do
      mock_next_step(:back_image)
      allow_any_instance_of(Flow::BaseFlow).to \
        receive(:flow_session).and_return(pii_from_doc: {})
      result = { success: true, errors: {}, step: 'ssn' }

      put :update, params: { step: 'ssn', doc_auth: { step: 'ssn', ssn: '111-11-1111' } }

      expect(@analytics).to have_received(:track_event).with(
        Analytics::DOC_AUTH + ' submitted', result
      )
    end

    describe 'when document capture is enabled' do
      before(:each) do
        allow(Figaro.env).to receive(:document_capture_step_enabled).and_return('true')
      end

      it 'progresses from welcome to upload' do
        put :update, params: { step: 'welcome', ial2_consent_given: true }

        expect(response).to redirect_to idv_doc_auth_step_url(step: :upload)
      end

      it 'skips from welcome to document capture' do
        put :update, params: { step: 'welcome', ial2_consent_given: true, skip_upload: true }

        expect(response).to redirect_to idv_doc_auth_step_url(step: :document_capture)
      end
    end

    describe 'when document capture is disabled' do
      before(:each) do
        allow(Figaro.env).to receive(:document_capture_step_enabled).and_return('false')
      end

      it 'progresses from welcome to upload' do
        put :update, params: { step: 'welcome', ial2_consent_given: true, skip_upload: true }

        expect(response).to redirect_to idv_doc_auth_step_url(step: :upload)
      end
    end
  end

  def mock_next_step(step)
    allow_any_instance_of(Idv::Flows::DocAuthFlow).to receive(:next_step).and_return(step)
  end
end
