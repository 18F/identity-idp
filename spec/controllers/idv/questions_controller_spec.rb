require 'rails_helper'

describe Idv::QuestionsController do
  render_views

  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:applicant) { Proofer::Applicant.new first_name: 'Some', last_name: 'One' }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start applicant }

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
    sign_in(user)
    @request.session[:idv_vendor] = :mock
    @request.session[:idv_applicant] = applicant
    @request.session[:idv_resolution] = resolution
    @request.session[:idv_question_number] = 0
  end
end
