require 'rails_helper'

describe Idv::QuestionsController do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:applicant) { Proofer::Applicant.new first_name: 'Some', last_name: 'One' }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start applicant }

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  context 'user has started proofing session' do
    render_views

    before(:each) do
      stub_idv_session
    end

    it 'retrieves next question' do
      get :index

      expect(response.body).to include resolution.questions.first.display
    end

    it 'answers question and advances' do
      post :create, answer: 'foo', question_key: resolution.questions.first.key

      expect(resolution.questions.first.answer).to eq 'foo'
      expect(response).to redirect_to(idv_questions_path)
    end
  end

  context 'user has not started proofing session' do
    it 'redirects to session start page' do
      stub_sign_in(user)

      get :index

      expect(response).to redirect_to(idv_session_path)
    end
  end

  def stub_idv_session
    stub_sign_in(user)
    subject.user_session[:idv] = {
      vendor: :mock,
      applicant: applicant,
      resolution: resolution,
      question_number: 0
    }
  end
end
