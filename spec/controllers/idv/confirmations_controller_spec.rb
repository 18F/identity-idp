require 'rails_helper'
require 'proofer/vendor/mock'

describe Idv::ConfirmationsController do
  include SamlAuthHelper

  render_views

  let(:password) { 'sekrit phrase' }
  let(:user) { create(:user, :signed_up, password: password, email: 'old_email@example.com') }
  let(:applicant) { Proofer::Applicant.new first_name: 'Some', last_name: 'One' }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start applicant }
  let(:profile) { Idv::Applicant.new(applicant, user, password).profile }

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_vendor_session_started
      )
    end
  end

  context 'session started' do
    before do
      stub_idv_session
    end

    context 'KBV off' do
      before do
        allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(false)
        allow(subject.idv_session).to receive(:questions).and_return(false)
      end

      it 'cleans up PII from session' do
        get :index

        expect(subject.idv_session.alive?).to eq false
      end
    end

    context 'KBV on' do
      before do
        allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(true)
      end

      context 'all questions correct' do
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
            expect(profile.verified_at).to_not be_nil
          end

          it 'redirects to original SAML Authn request' do
            expect(response).to redirect_to saml_authn_request
          end

          it 'cleans up PII from session' do
            expect(subject.idv_session.alive?).to eq false
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

        it 'redirects to retry' do
          expect(response).to redirect_to(idv_retry_url)
        end

        it 'does not save PII' do
          expect(Profile.where(id: profile.id).count).to eq 0
        end
      end

      context 'max attempts exceeded' do
        before do
          complete_idv_session(false)
          user.idv_attempts = 3
          user.idv_attempted_at = Time.zone.now
          get :index
        end

        it 'redirects to fail' do
          expect(response).to redirect_to(idv_fail_url)
        end
      end

      context 'questions incomplete' do
        it 'redirects to /idv/questions' do
          get :index

          expect(response).to redirect_to(idv_questions_path)
        end
      end
    end
  end

  context 'IdV session not yet started' do
    it 'redirects to /idv/sessions' do
      stub_sign_in(user)

      get :index

      expect(response).to redirect_to(idv_session_path)
    end
  end

  def stub_idv_session
    stub_sign_in(user)
    idv_session = Idv::Session.new(subject.user_session, user)
    idv_session.vendor = :mock
    idv_session.applicant = applicant
    idv_session.resolution = resolution
    idv_session.profile_id = profile.id
    idv_session.question_number = 0
    allow(subject).to receive(:idv_session).and_return(idv_session)
  end

  def complete_idv_session(answer_correctly)
    Proofer::Vendor::Mock::ANSWERS.each do |ques, answ|
      resolution.questions.find_by_key(ques).answer = answer_correctly ? answ : 'wrong'
      subject.idv_session.question_number += 1
    end
  end
end
