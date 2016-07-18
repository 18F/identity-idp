require 'rails_helper'

describe Idv::ConfirmationsController do
  render_views

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

  context 'session started' do
    before do
      init_idv_session
    end

    describe 'all questions answered correctly' do
      it 'shows success' do
        init_idv_session
        complete_idv_session(true)

        get :index

        expect(response.status).to eq 200
        expect(response.body).to include(t('idv.titles.complete'))
      end
    end

    describe 'some answers incorrect' do
      it 'shows error' do
        init_idv_session
        complete_idv_session(false)

        get :index

        expect(response.status).to eq 200
        expect(response.body).to include(t('idv.titles.hardfail'))
      end
    end

    describe 'questions incomplete' do
      it 'redirects to /idv/questions' do
        init_idv_session

        get :index

        expect(response).to redirect_to(idv_questions_path)
      end
    end
  end

  describe 'session not yet started' do
    it 'redirects to /idv/sessions' do
      sign_in(user)

      get :index

      expect(response).to redirect_to(idv_sessions_path)
    end
  end

  def init_idv_session
    sign_in(user)
    subject.user_session[:idv] = {
      vendor: :mock,
      applicant: applicant,
      resolution: resolution,
      question_number: 0
    }
  end

  def complete_idv_session(answer_correctly)
    Proofer::Vendor::Mock::ANSWERS.each do |ques, answ|
      resolution.questions.find_by_key(ques).answer = answer_correctly ? answ : 'wrong'
      subject.user_session[:idv][:question_number] += 1
    end
  end
end
