require 'rails_helper'

describe Verify::SessionsController do
  let(:max_attempts) { Idv::Attempter.idv_max_attempts }
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }
  let(:user_attrs) do
    {
      first_name: 'Some',
      last_name: 'One',
      ssn: '666-66-1234',
      dob: '19720329',
      address1: '123 Main St',
      address2: '',
      city: 'Somewhere',
      state: 'KS',
      zipcode: '66044'
    }
  end
  let(:idv_session) { Idv::Session.new(subject.user_session, user) }

  describe 'before_actions' do
    it 'includes before_actions from AccountStateChecker' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_attempts_allowed,
        :confirm_idv_needed,
        :confirm_step_needed
      )
    end
  end

  context 'user has created account' do
    render_views

    before do
      stub_sign_in(user)
      allow(subject).to receive(:idv_session).and_return(idv_session)
      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    describe '#new' do
      it 'starts new proofing session' do
        get :new

        expect(response.status).to eq 200
        expect(response.body).to include t('idv.form.first_name')
      end

      it 'redirects if step is complete' do
        idv_session.profile_confirmation = true

        get :new

        expect(response).to redirect_to verify_finance_path
      end

      context 'max attempts exceeded' do
        before do
          user.idv_attempts = max_attempts
          user.idv_attempted_at = Time.zone.now
        end

        it 'redirects to fail' do
          get :new

          result = {
            request_path: verify_session_path
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::IDV_MAX_ATTEMPTS_EXCEEDED, result)
          expect(response).to redirect_to verify_fail_url
        end
      end
    end

    describe '#create' do
      before do
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      context 'existing SSN' do
        it 'redirects to custom error' do
          create(:profile, pii: { ssn: '666-66-1234' })

          result = {
            success: false,
            idv_attempts_exceeded: false,
            errors: { ssn: [t('idv.errors.duplicate_ssn')] },
            vendor: { reasons: nil }
          }

          expect(@analytics).to receive(:track_event).
            with(Analytics::IDV_BASIC_INFO_SUBMITTED, result)

          post :create, profile: user_attrs.merge(ssn: '666-66-1234')

          expect(response).to redirect_to(verify_session_dupe_path)
          expect(flash[:error]).to match t('idv.errors.duplicate_ssn')
        end
      end

      context 'empty SSN' do
        it 'shows normal form with error' do
          post :create, profile: user_attrs.merge(ssn: '')

          expect(response).to_not redirect_to(verify_session_dupe_path)
          expect(response.body).to match t('errors.messages.blank')
        end
      end

      context 'missing fields' do
        it 'checks for required fields' do
          partial_attrs = user_attrs.dup
          partial_attrs.delete :first_name

          post :create, profile: partial_attrs

          expect(response).to render_template(:new)
          expect(response.body).to match t('errors.messages.blank')
        end
      end

      context 'un-resolvable attributes' do
        let(:bad_attrs) { user_attrs.dup.merge(first_name: 'Bad') }

        it 're-renders form' do
          post :create, profile: bad_attrs

          expect(response).to render_template(:new)
        end

        it 'creates analytics event' do
          post :create, profile: bad_attrs

          result = {
            success: false,
            idv_attempts_exceeded: false,
            errors: {
              first_name: ['Unverified first name.']
            },
            vendor: { reasons: ['The name was suspicious'] }
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::IDV_BASIC_INFO_SUBMITTED, result)
        end
      end

      context 'success' do
        it 'creates analytics event' do
          post :create, profile: user_attrs

          result = {
            success: true,
            idv_attempts_exceeded: false,
            errors: {},
            vendor: { reasons: ['Everything looks good'] }
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::IDV_BASIC_INFO_SUBMITTED, result)
        end
      end

      context 'max attempts exceeded' do
        before do
          user.idv_attempts = max_attempts
          user.idv_attempted_at = Time.zone.now
        end

        it 'redirects to fail' do
          post :create, profile: user_attrs

          result = {
            request_path: verify_session_path
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::IDV_MAX_ATTEMPTS_EXCEEDED, result)
          expect(response).to redirect_to verify_fail_url
        end
      end

      context 'attempt window has expired, previous attempts == max-1' do
        before do
          user.idv_attempts = max_attempts - 1
          user.idv_attempted_at = Time.zone.now - 2.days
        end

        it 'allows and resets attempt counter' do
          post :create, profile: user_attrs

          expect(response).to redirect_to verify_finance_path
          expect(user.idv_attempts).to eq 1
        end
      end
    end
  end
end
