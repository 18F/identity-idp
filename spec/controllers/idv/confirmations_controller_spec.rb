require 'rails_helper'
require 'proofer/vendor/mock'

describe Idv::ConfirmationsController do
  include SamlAuthHelper

  render_views

  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:applicant) { Proofer::Applicant.new first_name: 'Some', last_name: 'One' }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start applicant }
  let(:profile) { Profile.create_from_proofer_applicant(applicant, user) }

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

    context 'all answers correct' do
      context 'original SAML Authn request present' do
        let(:saml_authn_request) { sp1_authnrequest }

        before do
          subject.session[:saml_request_url] = saml_authn_request
          complete_idv_session(true)
          get :index
        end

        it 'activates profile' do
          profile.reload

          expect(profile).to be_active
          expect(profile).to be_verified
        end

        it 'redirects to original SAML Authn request' do
          expect(response).to redirect_to saml_authn_request
        end

        it 'cleans up PII from session' do
          expect(subject.user_session[:idv][:applicant]).to eq nil
        end
      end

      context 'original SAML Authn request missing' do
        before do
          subject.session[:saml_request_url] = nil
          complete_idv_session(true)
          get :index
        end

        it 'redirects to IdP profile' do
          expect(response).to redirect_to(profile_path)
        end
      end
    end

    context 'some answers incorrect' do
      before do
        complete_idv_session(false)
        get :index
      end

      it 'shows error' do
        expect(response.status).to eq 200
        expect(response.body).to include(t('idv.titles.hardfail'))
      end

      it 'does not save PII' do
        expect(Profile.where(id: profile.id).count).to eq 0
      end
    end

    context 'questions incomplete' do
      it 'redirects to /idv/questions' do
        get :index

        expect(response).to redirect_to(idv_questions_path)
      end
    end
  end

  context 'session not yet started' do
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
      profile_id: profile.id,
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
