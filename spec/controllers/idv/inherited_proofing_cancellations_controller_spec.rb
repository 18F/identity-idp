require 'rails_helper'

shared_examples 'an HTML 404 not found' do
  it 'returns a 404 not found' do
    expect(response).to have_http_status(:not_found)
  end
end

describe Idv::InheritedProofingCancellationsController do
  let(:step) { Idv::Flows::InheritedProofingFlow::STEPS.keys.first }

  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end

    it 'includes before_actions from InheritedProofing404Concern' do
      expect(subject).to have_actions(:before, :render_404_if_disabled)
    end

    it 'includes before_actions from AllowlistedFlowStepConcern' do
      expect(subject).to have_actions(:before, :flow_step!)
    end
  end

  describe '#new' do
    let(:go_back_path) { '/path/to/return' }

    before do
      allow(controller).to receive(:go_back_path).and_return(go_back_path)
    end

    context 'when the inherited proofing feature flipper is turned off' do
      before do
        allow(IdentityConfig.store).to receive(:inherited_proofing_enabled).and_return(false)
        stub_sign_in
      end

      describe '#new' do
        before do
          get :new, params: { step: step }
        end

        it_behaves_like 'an HTML 404 not found'
      end

      describe '#update' do
        before do
          get :update, params: { step: step }
        end

        it_behaves_like 'an HTML 404 not found'
      end

      describe '#destroy' do
        before do
          get :destroy, params: { step: step }
        end

        it_behaves_like 'an HTML 404 not found'
      end
    end

    context 'when the flow step is not in the allowed list' do
      before do
        stub_sign_in
      end

      let(:step) { :not_found_step }
      let(:expected_logger_warning) { "Flow step param \"#{step})\" was not whitelisted!" }

      describe '#new' do
        before do
          expect(Rails.logger).to receive(:warn).with(expected_logger_warning)
          get :new, params: { step: step }
        end

        it_behaves_like 'an HTML 404 not found'
      end

      describe '#update' do
        before do
          expect(Rails.logger).to receive(:warn).with(expected_logger_warning)
          get :update, params: { step: step }
        end

        it_behaves_like 'an HTML 404 not found'
      end

      describe '#destroy' do
        before do
          expect(Rails.logger).to receive(:warn).with(expected_logger_warning)
          get :destroy, params: { step: step }
        end

        it_behaves_like 'an HTML 404 not found'
      end
    end

    context 'when there is no session' do
      it 'redirects to root' do
        get :new

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when there is a session' do
      before do
        stub_sign_in
      end

      it 'renders template' do
        get :new, params: { step: step }

        expect(response).to render_template(:new)
      end

      it 'stores go back path' do
        get :new, params: { step: step }

        expect(controller.user_session[:idv][:go_back_path]).to eq(go_back_path)
      end
    end
  end

  describe '#update' do
    before do
      stub_sign_in
    end

    it 'redirects to idv_inherited_proofing_path' do
      put :update, params: { step: step, cancel: 'true' }

      expect(response).to redirect_to idv_inherited_proofing_url
    end

    context 'when a go back path is stored in session' do
      let(:go_back_path) { '/path/to/return' }

      before do
        allow(controller).to receive(:user_session).and_return(
          idv: { go_back_path: go_back_path },
        )
      end

      it 'redirects to go back path' do
        put :update, params: { step: step, cancel: 'true' }

        expect(response).to redirect_to go_back_path
      end
    end
  end

  describe '#destroy' do
    context 'when there is no session' do
      it 'redirects to root' do
        delete :destroy, params: { step: step }

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when there is a session' do
      let(:user) { create(:user) }

      before do
        stub_sign_in user
      end

      before do
        allow(controller).to receive(:user_session).
          and_return(idv: { go_back_path: '/path/to/return' })
      end

      it 'destroys session' do
        expect(subject).to receive(:cancel_session).once

        delete :destroy, params: { step: step }
      end

      it 'renders a json response with the redirect path set to account_path' do
        delete :destroy, params: { step: step }

        parsed_body = JSON.parse(response.body, symbolize_names: true)
        expect(response).not_to render_template(:destroy)
        expect(parsed_body).to eq({ redirect_url: account_path })
      end
    end
  end
end
