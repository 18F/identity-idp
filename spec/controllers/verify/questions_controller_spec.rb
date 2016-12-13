require 'rails_helper'

describe Verify::QuestionsController do
  include IdvHelper
  include SamlAuthHelper

  let(:password) { 'sekrit phrase' }
  let(:user) { create(:user, :signed_up, password: password, email: 'old_email@example.com') }
  let(:applicant) { Proofer::Applicant.new first_name: 'Some', last_name: 'One' }
  let(:agent) { Proofer::Agent.new vendor: :mock }
  let(:resolution) { agent.start applicant }
  let(:profile) do
    user.unlock_user_access_key(password)
    Idv::ProfileFromApplicant.create(applicant, user)
  end

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated
      )
    end
  end

  context 'user has started proofing session' do
    before(:each) do
      stub_idv_session
    end

    context 'KBV on' do
      before do
        allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(true)
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      context 'more questions available' do
        render_views

        it 'retrieves next question' do
          get :index

          expect(response.body).to include resolution.questions.first.display
        end
      end

      it 'answers question and advances' do
        post :create, answer: 'foo', question_key: resolution.questions.first.key

        expect(resolution.questions.first.answer).to eq 'foo'
        expect(response).to redirect_to(verify_questions_path)
      end

      context 'all questions correct' do
        context 'original SAML Authn request present' do
          let(:saml_authn_request) { sp1_authnrequest }

          before do
            subject.session[:saml_request_url] = saml_authn_request
            complete_idv_session(true)
            get :index
          end

          it 'redirects to confirmations path and tracks event' do
            result = {
              kbv_passed: true,
              idv_attempts_exceeded: false,
              new_phone_added: false
            }

            expect(@analytics).to have_received(:track_event).with(Analytics::IDV_FINAL, result)
            expect(response).to redirect_to(verify_confirmations_path)
          end
        end

        context 'original SAML Authn request missing' do
          before do
            subject.session[:saml_request_url] = nil
            complete_idv_session(true)
            get :index
          end

          it 'redirects to confirmations path' do
            expect(response).to redirect_to(verify_confirmations_path)
          end
        end
      end

      context 'some answers incorrect' do
        before do
          complete_idv_session(false)
          get :index
        end

        it 'redirects to retry and tracks event' do
          result = {
            kbv_passed: false,
            idv_attempts_exceeded: false,
            new_phone_added: false
          }

          expect(@analytics).to have_received(:track_event).with(Analytics::IDV_FINAL, result)
          expect(response).to redirect_to(verify_retry_path)
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

        it 'redirects to fail and tracks event' do
          result = {
            kbv_passed: false,
            idv_attempts_exceeded: true,
            new_phone_added: false
          }

          expect(@analytics).to have_received(:track_event).with(Analytics::IDV_FINAL, result)
          expect(response).to redirect_to(verify_fail_path)
        end
      end

      context 'user confirmed a new phone' do
        it 'tracks that event' do
          subject.idv_session.params['phone_confirmed_at'] = Time.current
          complete_idv_session(true)
          get :index

          result = {
            kbv_passed: true,
            idv_attempts_exceeded: false,
            new_phone_added: true
          }

          expect(@analytics).to have_received(:track_event).with(Analytics::IDV_FINAL, result)
        end
      end
    end

    context 'KBV is off' do
      it 'redirects to confirmations path' do
        get :index

        expect(response).to redirect_to(verify_confirmations_path)
      end
    end
  end

  context 'user has not started proofing session' do
    it 'redirects to session start page' do
      stub_sign_in(user)

      get :index

      expect(response).to redirect_to(verify_session_path)
    end
  end
end
