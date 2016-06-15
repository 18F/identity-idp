require 'rails_helper'

describe Idv::QuestionsController do
  render_views

  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start }

  context 'user has started proofing session' do
    it 'retrieves next question' do
      init_idv_session

      get :index

      expect(response.body).to include resolution.questions.first.display
    end

    it 'answers question and advances' do
      init_idv_session

      post :create, { answer: 'foo', question_key: resolution.questions.first.key }

      expect(resolution.questions.first.answer).to eq 'foo'
      expect(response).to redirect_to(idv_questions_path)
    end
  end

  def init_idv_session
    @request.session[:resolution] = resolution
    @request.session[:question_number] = 0
  end
end
