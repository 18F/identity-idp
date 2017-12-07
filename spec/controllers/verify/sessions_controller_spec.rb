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
      zipcode: '66044',
    }
  end
  let(:previous_address) do
    {
      prev_address1: '456 Other St',
      prev_address2: '',
      prev_city: 'Elsewhere',
      prev_state: 'MO',
      prev_zipcode: '66666',
    }
  end
  let(:idv_session) do
    Idv::Session.new(user_session: subject.user_session, current_user: user, issuer: nil)
  end
  let(:normalized_applicant) { Proofer::Applicant.new(user_attrs) }

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
      end

      it 'redirects if step is complete' do
        idv_session.profile_confirmation = true

        get :new

        expect(response).to redirect_to verify_address_path
      end

      context 'max attempts exceeded' do
        before do
          user.idv_attempts = max_attempts
          user.idv_attempted_at = Time.zone.now
        end

        it 'redirects to fail' do
          get :new

          result = {
            request_path: verify_session_path,
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

      context 'UUID' do
        it 'assigned user UUID to applicant' do
          post :create, params: { profile: user_attrs }

          expect(subject.idv_session.applicant['uuid']).to eq subject.current_user.uuid
        end
      end

      context 'existing SSN' do
        it 'redirects to custom error' do
          create(:profile, pii: { ssn: '666-66-1234' })

          result = {
            success: false,
            errors: { ssn: [t('idv.errors.duplicate_ssn')] },
          }

          expect(@analytics).to receive(:track_event).
            with(Analytics::IDV_BASIC_INFO_SUBMITTED_FORM, result)

          post :create, params: { profile: user_attrs.merge(ssn: '666-66-1234') }

          expect(response).to redirect_to(verify_session_dupe_path)
          expect(flash[:error]).to match t('idv.errors.duplicate_ssn')
        end
      end

      context 'empty SSN' do
        it 'renders the form' do
          post :create, params: { profile: user_attrs.merge(ssn: '') }

          expect(response).to_not redirect_to(verify_session_dupe_path)
          expect(response).to render_template(:new)
        end
      end

      context 'missing fields' do
        let(:partial_attrs) do
          user_attrs.tap { |attrs| attrs.delete :first_name }
        end

        it 'checks for required fields' do
          post :create, params: { profile: partial_attrs }

          expect(response).to render_template(:new)
          expect(flash[:warning]).to be_nil
        end

        it 'does not increment attempts count' do
          expect { post :create, params: { profile: partial_attrs } }.
            to_not change(user, :idv_attempts)
        end
      end
    end

    describe '#show' do
      before do
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      context 'when the background job is not complete yet' do
        render_views

        it 'renders a spinner and has the page refresh' do
          get :show

          expect(response).to render_template('shared/refresh')

          dom = Nokogiri::HTML(response.body)
          expect(dom.css('meta[http-equiv="refresh"]')).to be_present
        end
      end

      context 'when the background job has timed out' do
        let(:expired_started_at) do
          Time.zone.now.to_i - Figaro.env.async_job_refresh_max_wait_seconds.to_i
        end

        before do
          controller.idv_session.async_result_started_at = expired_started_at
          controller.idv_session.params = user_attrs
        end

        it 'displays an error' do
          get :show

          expect(response).to render_template :new
          expect(flash[:warning]).to include(t('idv.modal.sessions.timeout'))
        end

        it 'tracks the failure as a timeout' do
          stub_analytics
          allow(@analytics).to receive(:track_event)

          get :show

          result = {
            success: false,
            errors: { timed_out: ['Timed out waiting for vendor response'] },
            idv_attempts_exceeded: false,
            vendor: { reasons: [] },
          }

          expect(@analytics).to have_received(:track_event).with(
            Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, result
          )
        end
      end

      context 'when the background job has completed' do
        let(:result_id) { SecureRandom.uuid }
        let(:params) { user_attrs }

        before do
          controller.idv_session.async_result_id = result_id
          VendorValidatorResultStorage.new.store(result_id: result_id, result: result)

          controller.idv_session.params = params
        end

        context 'un-resolvable attributes' do
          let(:params) { user_attrs.dup.merge(first_name: 'Bad') }

          let(:result) do
            Idv::VendorResult.new(
              success: false,
              errors: { first_name: ['Unverified first name.'] },
              reasons: ['The name was suspicious']
            )
          end

          it 're-renders form' do
            get :show

            expect(flash[:warning]).to match t('idv.modal.sessions.heading')
            expect(flash[:warning]).to match(t('idv.modal.attempts', count: max_attempts - 1))
            expect(response).to render_template(:new)
          end

          it 'creates analytics event' do
            get :show

            result = {
              success: false,
              idv_attempts_exceeded: false,
              errors: {
                first_name: ['Unverified first name.'],
              },
              vendor: { reasons: ['The name was suspicious'] },
            }

            expect(@analytics).to have_received(:track_event).
              with(Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, result)
          end
        end

        context 'previous address supplied' do
          let(:bad_zipcode) { '00000' }

          let(:result) { Idv::VendorResult.new(success: false) }

          context 'if previous address has a bad zipcode' do
            let(:params) { user_attrs.merge(previous_address).merge(prev_zipcode: bad_zipcode) }

            it 'fails' do
              get :show

              expect(idv_session.resolution_successful).to be_nil
            end
          end

          context 'if current address has a bad zipcode' do
            let(:params) { user_attrs.merge(previous_address).merge(zipcode: bad_zipcode) }

            it 'fails' do
              get :show

              expect(idv_session.resolution_successful).to be_nil
            end
          end

          context 'with multiple addresses' do
            let(:result) do
              Idv::VendorResult.new(success: true, normalized_applicant: normalized_applicant)
            end
            let(:params) { user_attrs.merge(previous_address) }

            it 'respects both addresses' do
              get :show

              expect(idv_session.resolution_successful).to eq true
            end
          end
        end

        context 'vendor agent throws exception' do
          let(:params) { user_attrs.dup.merge(first_name: 'Fail') }
          let(:exception_msg) { 'Failed to contact proofing vendor' }
          let(:result) do
            Idv::VendorResult.new(
              success: false,
              errors: { agent: [exception_msg] },
              reasons: [exception_msg]
            )
          end

          it 'logs failure and re-renders form' do
            get :show

            result = {
              success: false,
              idv_attempts_exceeded: false,
              errors: {
                agent: [exception_msg],
              },
              vendor: { reasons: [exception_msg] },
            }

            expect(@analytics).to have_received(:track_event).
              with(Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, result)
            expect(response).to render_template(:new)
          end
        end

        context 'success' do
          let(:result) do
            Idv::VendorResult.new(
              success: true,
              reasons: ['Everything looks good'],
              normalized_applicant: normalized_applicant
            )
          end

          it 'creates analytics event' do
            get :show

            result = {
              success: true,
              idv_attempts_exceeded: false,
              errors: {},
              vendor: { reasons: ['Everything looks good'] },
            }

            expect(@analytics).to have_received(:track_event).
              with(Analytics::IDV_BASIC_INFO_SUBMITTED_VENDOR, result)
          end

          it 'increments attempts count' do
            expect { get :show }.to change(user, :idv_attempts).by(1)
          end
        end

        context 'max attempts exceeded' do
          let(:result) { Idv::VendorResult.new(success: true) }

          before do
            user.idv_attempts = max_attempts
            user.idv_attempted_at = Time.zone.now
          end

          it 'redirects to fail' do
            get :show

            result = {
              request_path: verify_session_result_path,
            }

            expect(@analytics).to have_received(:track_event).
              with(Analytics::IDV_MAX_ATTEMPTS_EXCEEDED, result)
            expect(response).to redirect_to verify_fail_url
          end
        end

        context 'attempt window has expired, previous attempts == max-1' do
          let(:result) do
            Idv::VendorResult.new(success: true, normalized_applicant: normalized_applicant)
          end

          before do
            user.idv_attempts = max_attempts - 1
            user.idv_attempted_at = Time.zone.now - 2.days
          end

          it 'allows and resets attempt counter' do
            get :show

            expect(response).to redirect_to verify_address_path
            expect(user.idv_attempts).to eq 1
          end
        end
      end
    end

    describe '#destroy' do
      it 'clears the idv session and returns the user to their profile' do
        delete :destroy

        expect(controller.user_session[:idv]).to eq({})
        expect(response).to redirect_to(account_path)
      end
    end
  end
end
