require 'rails_helper'

RSpec.describe Idv::ByMail::EnterCodeController do
  let(:good_otp) { 'ABCDE12345' }
  let(:bad_otp) { 'bad-otp' }
  let(:threatmetrix_enabled) { false }
  let(:gpo_enabled) { true }
  let(:pii_cacher) { Pii::Cacher.new(user, controller.user_session) }
  let(:params) { nil }

  before do
    stub_analytics
    stub_attempts_tracker
    stub_sign_in(user)

    allow(Pii::Cacher).to receive(:new).and_return(pii_cacher)
    allow(pii_cacher).to receive(:fetch).and_call_original
    allow(UserAlerts::AlertUserAboutAccountVerified).to receive(:call)
    allow(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_submitted)
    allow(IdentityConfig.store).to receive(:proofing_device_profiling).
      and_return(threatmetrix_enabled ? :enabled : :disabled)
    allow(IdentityConfig.store).to receive(:enable_usps_verification).and_return(gpo_enabled)
  end

  describe '#index' do
    subject(:action) { get(:index, params: params) }

    context 'user has pending profile' do
      let(:profile_created_at) { 2.days.ago }
      let(:user) { create(:user, :with_pending_gpo_profile, created_at: profile_created_at) }
      let(:pending_profile) { user.gpo_verification_pending_profile }

      before do
        controller.user_session[:decrypted_pii] = { address1: 'Address1' }.to_json
      end

      it 'renders page' do
        action

        expect(@analytics).to have_logged_event(
          'IdV: enter verify by mail code visited',
          source: nil,
        )
        expect(response).to render_template('idv/by_mail/enter_code/index')
      end

      it 'uses the PII from the pending profile' do
        action
        expect(pii_cacher).to have_received(:fetch).with(pending_profile.id)
      end

      it 'sets @can_request_another_letter to true' do
        action
        expect(assigns(:can_request_another_letter)).to eql(true)
      end

      context 'when the user is rate limited' do
        before do
          RateLimiter.new(rate_limit_type: :verify_gpo_key, user: user).increment_to_limited!
        end

        it 'shows rate limited page' do
          action

          expect(response).to redirect_to(idv_enter_code_rate_limited_url)
        end

        it 'logs an analytics event' do
          action

          expect(@analytics).to have_logged_event(
            'IdV: enter verify by mail code visited',
            source: nil,
          )
        end
      end

      context 'but that profile is too old' do
        let(:profile_created_at) { 31.days.ago }

        it 'sets @can_request_another_letter to false' do
          action
          expect(assigns(:can_request_another_letter)).to eql(false)
        end
      end

      context 'user clicked a "i did not receive my letter" link' do
        let(:params) { { did_not_receive_letter: 1 } }

        it 'sets @user_did_not_receive_letter to true' do
          action
          expect(assigns(:user_did_not_receive_letter)).to eql(true)
        end

        it 'augments analytics event' do
          action
          expect(@analytics).to have_logged_event(
            'IdV: enter verify by mail code visited',
            source: 'gpo_reminder_email',
          )
        end
      end
    end

    context 'user does not have a pending profile' do
      let(:user) { create(:user) }

      it 'uses no PII' do
        action

        expect(pii_cacher).not_to have_received(:fetch)
      end

      it 'redirects to account page' do
        action

        expect(response).to redirect_to(account_url)
      end
    end

    context 'session says user did not receive letter' do
      let(:user) { create(:user, :with_pending_gpo_profile, created_at: 2.days.ago) }

      before do
        session[:gpo_user_did_not_receive_letter] = true
      end

      it 'redirects user to url with querystring' do
        action
        expect(response).to redirect_to(
          idv_verify_by_mail_enter_code_path(did_not_receive_letter: 1),
        )
      end

      it 'clears session value' do
        action
        expect(session).not_to include(gpo_user_did_not_receive_letter: anything)
      end
    end

    context 'not logged in, and querystring says user did not receive letter' do
      let(:user) { nil }
      let(:params) { { did_not_receive_letter: 1 } }

      it 'sets value in session' do
        expect { action }.to change { session[:gpo_user_did_not_receive_letter ] }.to eql(true)
      end
    end
  end

  describe '#create' do
    let(:otp_code_error_message) { { otp: [t('errors.messages.confirmation_code_incorrect')] } }
    let(:success_properties) { { success: true } }

    context 'user does not have a pending profile' do
      let(:user) { create(:user, :fully_registered) }

      it 'uses no PII' do
        expect(pii_cacher).not_to have_received(:fetch)
      end
    end

    context 'with a valid form' do
      subject(:action) do
        post(:create, params: { gpo_verify_form: { otp: good_otp } })
      end

      let(:user) { create(:user, :with_pending_gpo_profile, created_at: 2.days.ago) }
      let!(:pending_profile) { user.gpo_verification_pending_profile }
      let(:success) { true }

      it 'uses the PII from the pending profile' do
        # action will make the profile active, so grab the ID here.
        pending_profile_id = pending_profile.id

        action
        expect(pii_cacher).to have_received(:fetch).with(pending_profile_id)
      end

      it 'redirects to the sign_up/completions page' do
        action

        expect(@irs_attempts_api_tracker).to have_received(:idv_gpo_verification_submitted).
          with(success_properties)

        expect(@analytics).to have_logged_event(
          'IdV: enter verify by mail code submitted',
          success: true,
          errors: {},
          pending_in_person_enrollment: false,
          fraud_check_failed: false,
          enqueued_at: pending_profile.gpo_confirmation_codes.last.code_sent_at,
          which_letter: 1,
          letter_count: 1,
          attempts: 1,
        )
        event_count = user.events.where(event_type: :account_verified, ip: '0.0.0.0').
          where(disavowal_token_fingerprint: nil).count
        expect(event_count).to eq 1
        expect(response).to redirect_to(idv_personal_key_url)
      end

      it 'dispatches account verified alert' do
        action

        expect(UserAlerts::AlertUserAboutAccountVerified).to have_received(:call)
      end

      context 'with establishing in person enrollment' do
        let!(:enrollment) do
          create(
            :in_person_enrollment,
            :pending,
            user: user,
            profile: user.pending_profile,
          )
        end

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(controller).to receive(:pii).
            and_return(user.pending_profile.decrypt_pii(user.password).to_h)
        end

        it 'redirects to personal key page' do
          action

          expect(@irs_attempts_api_tracker).to have_received(:idv_gpo_verification_submitted).
            with(success_properties)

          expect(@analytics).to have_logged_event(
            'IdV: enter verify by mail code submitted',
            success: true,
            errors: {},
            pending_in_person_enrollment: true,
            fraud_check_failed: false,
            enqueued_at: pending_profile.gpo_confirmation_codes.last.code_sent_at,
            which_letter: 1,
            letter_count: 1,
            attempts: 1,
          )
          expect(response).to redirect_to(idv_personal_key_url)
        end

        it 'does not dispatch account verified alert' do
          action

          expect(UserAlerts::AlertUserAboutAccountVerified).not_to have_received(:call)
        end
      end

      context 'threatmetrix disabled' do
        context 'with threatmetrix status of "reject"' do
          let(:user) { create(:user, :gpo_pending_with_fraud_rejection) }

          it 'redirects to the sign_up/completions page' do
            action

            expect(@irs_attempts_api_tracker).to have_received(:idv_gpo_verification_submitted).
              with(success_properties)

            expect(@analytics).to have_logged_event(
              'IdV: enter verify by mail code submitted',
              success: true,
              errors: {},
              pending_in_person_enrollment: false,
              fraud_check_failed: true,
              enqueued_at: pending_profile.gpo_confirmation_codes.last.code_sent_at,
              which_letter: 1,
              letter_count: 1,
              attempts: 1,
            )
            event_count = user.events.where(event_type: :account_verified, ip: '0.0.0.0').
              where(disavowal_token_fingerprint: nil).count
            expect(event_count).to eq 1
            expect(response).to redirect_to(idv_personal_key_url)
          end
        end
      end

      context 'threatmetrix enabled' do
        let(:threatmetrix_enabled) { true }

        context 'with threatmetrix status of "reject"' do
          let(:user) { create(:user, :gpo_pending_with_fraud_rejection) }

          it 'is reflected in analytics' do
            action

            expect(@analytics).to have_logged_event(
              'IdV: enter verify by mail code submitted',
              success: true,
              errors: {},
              pending_in_person_enrollment: false,
              fraud_check_failed: true,
              enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
              which_letter: 1,
              letter_count: 1,
              attempts: 1,
            )

            expect(response).to redirect_to(idv_personal_key_url)
          end

          it 'does not show a flash message' do
            action
            expect(flash[:success]).to be_nil
          end

          it 'does not dispatch account verified alert' do
            action

            expect(UserAlerts::AlertUserAboutAccountVerified).not_to have_received(:call)
          end
        end

        context 'with threatmetrix status of "review"' do
          let(:user) { create(:user, :gpo_pending_with_fraud_review) }

          it 'is reflected in analytics' do
            action

            expect(@analytics).to have_logged_event(
              'IdV: enter verify by mail code submitted',
              success: true,
              errors: {},
              pending_in_person_enrollment: false,
              fraud_check_failed: true,
              enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
              which_letter: 1,
              letter_count: 1,
              attempts: 1,
            )

            expect(response).to redirect_to(idv_personal_key_url)
          end
        end
      end
    end

    context 'with an invalid form' do
      subject(:action) do
        post(:create, params: { gpo_verify_form: { otp: bad_otp } })
      end

      let(:user) { create(:user, :with_pending_gpo_profile, created_at: 2.days.ago) }

      it 'redirects to the index page to show errors' do
        action

        expect(@irs_attempts_api_tracker).to have_received(:idv_gpo_verification_submitted).
          with(success: false)

        expect(@analytics).to have_logged_event(
          'IdV: enter verify by mail code submitted',
          success: false,
          errors: otp_code_error_message,
          pending_in_person_enrollment: false,
          fraud_check_failed: false,
          enqueued_at: nil,
          which_letter: nil,
          letter_count: 1,
          attempts: 1,
          error_details: { otp: { confirmation_code_incorrect: true } },
        )
        expect(response).to redirect_to(idv_verify_by_mail_enter_code_url)
      end

      it 'does not 500 with missing form keys' do
        expect { post(:create, params: {}) }.to raise_exception(
          ActionController::ParameterMissing,
        )
      end
    end

    context 'final attempt before rate limited' do
      let(:user) { create(:user, :with_pending_gpo_profile) }
      let(:max_attempts) { 2 }

      before do
        allow(IdentityConfig.store).to receive(:verify_gpo_key_max_attempts).
          and_return(max_attempts)
        (max_attempts - 1).times do |i|
          post(:create, params: { gpo_verify_form: { otp: bad_otp } })
        end
      end

      context 'invalid code is submitted' do
        it 'redirects to the rate limited index page to show errors' do
          analytics_args = {
            success: false,
            errors: otp_code_error_message,
            pending_in_person_enrollment: false,
            fraud_check_failed: false,
            enqueued_at: nil,
            which_letter: nil,
            letter_count: 1,
            attempts: 1,
            error_details: { otp: { confirmation_code_incorrect: true } },
          }
          post(:create, params: { gpo_verify_form: { otp: bad_otp } })

          expect(@analytics).to have_logged_event(
            'IdV: enter verify by mail code submitted',
            **analytics_args,
          )

          analytics_args[:attempts] = 2

          expect(@analytics).to have_logged_event(
            'IdV: enter verify by mail code submitted',
            **analytics_args,
          )

          expect(response).to redirect_to(idv_enter_code_rate_limited_url)
        end
      end

      context 'valid code is submitted' do
        let(:user) { create(:user, :with_pending_gpo_profile) }

        it 'redirects to personal key page' do
          post(:create, params: { gpo_verify_form: { otp: good_otp } })

          expect(@irs_attempts_api_tracker).to have_received(:idv_gpo_verification_submitted).
            exactly(max_attempts).times

          failed_gpo_submission_events =
            @analytics.events['IdV: enter verify by mail code submitted'].
              reject { |event_attributes| event_attributes[:errors].empty? }

          successful_gpo_submission_events =
            @analytics.events['IdV: enter verify by mail code submitted'].
              select { |event_attributes| event_attributes[:errors].empty? }

          expect(failed_gpo_submission_events.count).to eq(max_attempts - 1)
          expect(successful_gpo_submission_events.count).to eq(1)
          expect(response).to redirect_to(idv_personal_key_url)
        end
      end
    end
  end
end
