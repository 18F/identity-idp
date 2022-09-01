require 'rails_helper'

describe Idv::CaptureDocController do
  include DocAuthHelper
  include DocCaptureHelper

  describe 'before_actions' do
    it 'includes corrects before_actions' do
      expect(subject).to have_actions(
        :before,
        :ensure_user_id_in_session,
        :fsm_initialize,
        :ensure_correct_step,
      )
    end
  end

  let(:user) { create(:user) }

  before do
    stub_analytics
    stub_attempts_tracker
    allow(@analytics).to receive(:track_event)
    allow(@irs_attempts_api_tracker).to receive(:idv_phone_upload_link_used)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', domain: 'example.com'))
  end

  describe '#index' do
    let!(:session_uuid) do
      DocumentCaptureSession.create!(requested_at: Time.zone.now).uuid
    end

    context 'with no session' do
      it 'redirects to the root url' do
        get :index

        expected_params = ActionController::Parameters.new(
          { 'controller' => 'idv/capture_doc',
            'action' => 'index' },
        )

        expect(@irs_attempts_api_tracker).to have_received(:idv_phone_upload_link_used).with(
          { document_capture_session: nil, request_id: nil },
        )

        expect(response).to redirect_to root_url
      end
    end

    context 'with a bad session' do
      it 'redirects to the root url' do
        get :index, params: { 'document-capture-session': 'foo' }

        expected_params = ActionController::Parameters.new(
          { 'document-capture-session' => 'foo',
            'controller' => 'idv/capture_doc',
            'action' => 'index' },
        )

        expect(@irs_attempts_api_tracker).to have_received(:idv_phone_upload_link_used).with(
          { document_capture_session: nil, request_id: nil },
        )

        expect(response).to redirect_to root_url
      end
    end

    context 'with an expired token' do
      it 'redirects to the root url' do
        travel_to(Time.zone.now + 1.day) do
          get :index, params: { 'document-capture-session': session_uuid }
        end

        expected_params = ActionController::Parameters.new(
          {
            'document-capture-session' => session_uuid,
            'controller' => 'idv/capture_doc',
            'action' => 'index',
          },
        )

        expect(@irs_attempts_api_tracker).to have_received(:idv_phone_upload_link_used).with(
          { document_capture_session: nil, request_id: nil },
        )

        expect(response).to redirect_to root_url
      end
    end

    context 'with a good session uuid' do
      it 'redirects to the first step' do
        get :index, params: { 'document-capture-session': session_uuid }

        expected_params = ActionController::Parameters.new(
          {
            'document-capture-session' => session_uuid,
            'controller' => 'idv/capture_doc',
            'action' => 'index',
          },
        )

        expect(@irs_attempts_api_tracker).to have_received(:idv_phone_upload_link_used).with(
          { document_capture_session: nil, request_id: nil },
        )

        expect(response).to redirect_to idv_capture_doc_step_url(step: :document_capture)
      end
    end

    context 'with a user id in session and no session uuid' do
      it 'redirects to the first step' do
        mock_session(user.id)
        get :index

        expected_params = ActionController::Parameters.new(
          { 'controller' => 'idv/capture_doc',
            'action' => 'index' },
        )

        expect(@irs_attempts_api_tracker).to have_received(:idv_phone_upload_link_used).with(
          { document_capture_session: nil, request_id: nil },
        )

        expect(response).to redirect_to idv_capture_doc_step_url(step: :document_capture)
      end
    end
  end

  describe '#show' do
    context 'with a user id in session' do
      before do
        mock_session(user.id)
      end

      it 'renders the document_capture template' do
        expect(subject).to receive(:render).with(
          template: 'layouts/flow_step',
          locals: hash_including(
            :back_image_upload_url,
            :front_image_upload_url,
            :selfie_image_upload_url,
            :flow_session,
            step_template: 'idv/capture_doc/document_capture',
            flow_namespace: 'idv',
          ),
        ).and_call_original

        mock_next_step(:document_capture)
        get :show, params: { step: 'document_capture' }

        expect(@irs_attempts_api_tracker).not_to have_received(:idv_phone_upload_link_used)
      end

      it 'renders the capture_complete template' do
        expect(subject).to receive(:render).with(
          template: 'layouts/flow_step',
          locals: hash_including(
            :flow_session,
            step_template: 'idv/capture_doc/capture_complete',
            flow_namespace: 'idv',
          ),
        ).and_call_original

        mock_next_step(:capture_complete)
        get :show, params: { step: 'capture_complete' }

        expect(@irs_attempts_api_tracker).not_to have_received(:idv_phone_upload_link_used)
      end

      it 'renders a 404 with a non existent step' do
        get :show, params: { step: 'foo' }

        expect(@irs_attempts_api_tracker).not_to have_received(:idv_phone_upload_link_used)

        expect(response).to_not be_not_found
      end

      it 'tracks expected events' do
        mock_next_step(:capture_complete)
        result = { step: 'capture_complete', flow_path: 'hybrid', step_count: 1 }

        get :show, params: { step: 'capture_complete' }

        expect(@irs_attempts_api_tracker).not_to have_received(:idv_phone_upload_link_used)

        expect(@analytics).to have_received(:track_event).with(
          'IdV: ' + "#{Analytics::DOC_AUTH} capture_complete visited".downcase, result
        )
      end

      it 'increments the analytics step counts on subsequent submissions' do
        mock_next_step(:capture_complete)

        get :show, params: { step: 'capture_complete' }
        get :show, params: { step: 'capture_complete' }

        expect(@irs_attempts_api_tracker).not_to have_received(:idv_phone_upload_link_used)

        expect(@analytics).to have_received(:track_event).ordered.with(
          'IdV: ' + "#{Analytics::DOC_AUTH} capture_complete visited".downcase,
          hash_including(step: 'capture_complete', step_count: 1),
        )
        expect(@analytics).to have_received(:track_event).ordered.with(
          'IdV: ' + "#{Analytics::DOC_AUTH} capture_complete visited".downcase,
          hash_including(step: 'capture_complete', step_count: 2),
        )
      end
    end
  end

  def mock_next_step(step)
    allow_any_instance_of(Idv::Flows::CaptureDocFlow).to receive(:next_step).and_return(step)
  end

  def mock_session(user_id)
    session[:doc_capture_user_id] = user_id
  end
end
