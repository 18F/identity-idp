require 'rails_helper'

RSpec.describe Idv::GpoVerifyController do
  let(:has_pending_profile) { true }
  let(:success) { true }
  let(:otp) { 'ABC123' }
  let(:submitted_otp) { otp }
  let(:user) { create(:user) }
  let(:profile_created_at) { Time.zone.now }
  let(:pending_profile) do
    if user
      create(
        :profile,
        :with_pii,
        user: user,
        proofing_components: proofing_components,
        created_at: profile_created_at,
      )
    end
  end
  let(:proofing_components) { nil }
  let(:threatmetrix_enabled) { false }
  let(:gpo_enabled) { true }
  let(:params) { nil }

  before do
    stub_analytics
    stub_attempts_tracker

    if user
      stub_sign_in(user)
      pending_user = stub_user_with_pending_profile(user)
      create(
        :gpo_confirmation_code,
        profile: pending_profile,
        otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
      )
      allow(pending_user).to receive(:gpo_verification_pending_profile?).
        and_return(has_pending_profile)
    end

    allow(IdentityConfig.store).to receive(:proofing_device_profiling).
      and_return(threatmetrix_enabled ? :enabled : :disabled)
    allow(IdentityConfig.store).to receive(:enable_usps_verification).and_return(gpo_enabled)
  end

  describe '#index' do
    subject(:action) do
      get(:index, params: params)
    end

    context 'user has pending profile' do
      it 'renders page' do
        controller.user_session[:decrypted_pii] = { address1: 'Address1' }.to_json
        expect(@analytics).to receive(:track_event).with(
          'IdV: GPO verification visited',
          source: nil,
        )

        action

        expect(response).to render_template('idv/gpo_verify/index')
      end

      it 'sets @should_prompt_user_to_request_another_letter to true' do
        action
        expect(assigns(:should_prompt_user_to_request_another_letter)).to eql(true)
      end

      it 'shows rate limited page if user is rate limited' do
        RateLimiter.new(rate_limit_type: :verify_gpo_key, user: user).increment_to_limited!

        action

        expect(response).to render_template(:rate_limited)
      end

      context 'but that profile is > 30 days old' do
        let(:profile_created_at) { 31.days.ago }
        it 'sets @should_prompt_user_to_request_another_letter to false' do
          action
          expect(assigns(:should_prompt_user_to_request_another_letter)).to eql(false)
        end
      end

      context 'user clicked a "i did not receive my letter" link' do
        let(:params) do
          {
            did_not_receive_letter: 1,
          }
        end
        it 'sets @user_did_not_receive_letter to true' do
          action
          expect(assigns(:user_did_not_receive_letter)).to eql(true)
        end
        it 'augments analytics event' do
          action
          expect(@analytics).to have_logged_event(
            'IdV: GPO verification visited',
            source: 'gpo_reminder_email',
          )
        end
      end
    end

    context 'user does not have pending profile' do
      let(:has_pending_profile) { false }

      it 'redirects to account page' do
        action

        expect(response).to redirect_to(account_url)
      end
    end

    context 'with rate limit reached' do
      before do
        RateLimiter.new(rate_limit_type: :verify_gpo_key, user: user).increment_to_limited!
      end

      it 'renders rate limited page' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: GPO verification visited',
          source: nil,
        ).once
        expect(@analytics).to receive(:track_event).with(
          'Rate Limit Reached',
          limiter_type: :verify_gpo_key,
        ).once

        action

        expect(response).to render_template(:rate_limited)
      end
    end

    context 'session says user did not receive letter' do
      before do
        session[:gpo_user_did_not_receive_letter] = true
        action
      end
      it 'redirects user to url with querystring' do
        expect(response).to redirect_to(idv_gpo_verify_path(did_not_receive_letter: 1))
      end
      it 'clears session value' do
        expect(session).not_to include(gpo_user_did_not_receive_letter: anything)
      end
    end

    context 'querystring says user did not receive letter' do
      let(:params) do
        { did_not_receive_letter: 1 }
      end

      context 'not logged in' do
        let(:user) { nil }

        it 'sets value in session' do
          expect { action }.to change { session[:gpo_user_did_not_receive_letter ] }.to eql(true)
        end
      end
    end
  end

  describe '#create' do
    let(:otp_code_error_message) { { otp: [t('errors.messages.confirmation_code_incorrect')] } }
    let(:otp_code_incorrect) { { otp: [:confirmation_code_incorrect] } }
    let(:success_properties) { { success: true, failure_reason: nil } }

    subject(:action) do
      post(
        :create,
        params: {
          gpo_verify_form: {
            otp: submitted_otp,
          },
        },
      )
    end

    context 'with a valid form' do
      let(:success) { true }

      it 'redirects to the sign_up/completions page' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: GPO verification submitted',
          success: true,
          errors: {},
          pending_in_person_enrollment: false,
          fraud_check_failed: false,
          enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
          which_letter: 1,
          letter_count: 1,
          attempts: 1,
          pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        )
        expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_submitted).
          with(success_properties)

        action

        event_count = user.events.where(event_type: :account_verified, ip: '0.0.0.0').
          where(disavowal_token_fingerprint: nil).count
        expect(event_count).to eq 1
        expect(response).to redirect_to(idv_personal_key_url)
      end

      it 'dispatches account verified alert' do
        expect(UserAlerts::AlertUserAboutAccountVerified).to receive(:call)

        action
      end

      context 'with establishing in person enrollment' do
        let!(:enrollment) do
          create(
            :in_person_enrollment,
            :pending,
            user: user,
            profile: pending_profile,
          )
        end

        let(:proofing_components) do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        end

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(controller).to receive(:pii).
            and_return(user.pending_profile.decrypt_pii(user.password).to_h)
        end

        it 'redirects to personal key page' do
          expect(@analytics).to receive(:track_event).with(
            'IdV: GPO verification submitted',
            success: true,
            errors: {},
            pending_in_person_enrollment: true,
            fraud_check_failed: false,
            enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
            which_letter: 1,
            letter_count: 1,
            attempts: 1,
            pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
          )
          expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_submitted).
            with(success_properties)

          action

          expect(response).to redirect_to(idv_personal_key_url)
        end

        it 'does not dispatch account verified alert' do
          expect(UserAlerts::AlertUserAboutAccountVerified).not_to receive(:call)

          action
        end
      end

      context 'threatmetrix disabled' do
        context 'with threatmetrix status of "reject"' do
          let(:pending_profile) do
            create(
              :profile,
              :with_pii,
              fraud_pending_reason: 'threatmetrix_reject',
              user: user,
            )
          end

          it 'redirects to the sign_up/completions page' do
            expect(@analytics).to receive(:track_event).with(
              'IdV: GPO verification submitted',
              success: true,
              errors: {},
              pending_in_person_enrollment: false,
              fraud_check_failed: true,
              enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
              which_letter: 1,
              letter_count: 1,
              attempts: 1,
              pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
            )
            expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_submitted).
              with(success_properties)

            action

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
          let(:pending_profile) do
            create(
              :profile,
              :with_pii,
              fraud_pending_reason: 'threatmetrix_reject',
              user: user,
            )
          end

          it 'is reflected in analytics' do
            expect(@analytics).to receive(:track_event).with(
              'IdV: GPO verification submitted',
              success: true,
              errors: {},
              pending_in_person_enrollment: false,
              fraud_check_failed: true,
              enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
              which_letter: 1,
              letter_count: 1,
              attempts: 1,
              pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
            )

            action

            expect(response).to redirect_to(idv_personal_key_url)
          end

          it 'does not show a flash message' do
            expect(flash[:success]).to be_nil
            action
          end

          it 'does not dispatch account verified alert' do
            expect(UserAlerts::AlertUserAboutAccountVerified).not_to receive(:call)
            action
          end
        end

        context 'with threatmetrix status of "review"' do
          let(:pending_profile) do
            create(
              :profile,
              :with_pii,
              fraud_pending_reason: 'threatmetrix_review',
              user: user,
            )
          end

          it 'is reflected in analytics' do
            expect(@analytics).to receive(:track_event).with(
              'IdV: GPO verification submitted',
              success: true,
              errors: {},
              pending_in_person_enrollment: false,
              fraud_check_failed: true,
              enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
              which_letter: 1,
              letter_count: 1,
              attempts: 1,
              pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
            )

            action

            expect(response).to redirect_to(idv_personal_key_url)
          end
        end
      end
    end

    context 'with an invalid form' do
      let(:submitted_otp) { 'the-wrong-otp' }

      it 'redirects to the index page to show errors' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: GPO verification submitted',
          success: false,
          errors: otp_code_error_message,
          pending_in_person_enrollment: false,
          fraud_check_failed: false,
          enqueued_at: nil,
          which_letter: nil,
          letter_count: 1,
          attempts: 1,
          error_details: otp_code_incorrect,
          pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        )
        expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_submitted).
          with(success: false, failure_reason: otp_code_incorrect)

        action

        expect(response).to redirect_to(idv_gpo_verify_url)
      end

      it 'does not 500 with missing form keys' do
        expect { post(:create, params: { otp: submitted_otp }) }.to raise_exception(
          ActionController::ParameterMissing,
        )
      end
    end

    context 'final attempt before rate limited' do
      let(:invalid_otp) { 'a-wrong-otp' }
      let(:max_attempts) { IdentityConfig.store.verify_gpo_key_max_attempts }

      context 'user is rate limited' do
        it 'renders the index page to show errors' do
          analytics_args = {
            success: false,
            errors: otp_code_error_message,
            pending_in_person_enrollment: false,
            fraud_check_failed: false,
            enqueued_at: nil,
            which_letter: nil,
            letter_count: 1,
            attempts: 1,
            error_details: otp_code_incorrect,
            pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
          }
          expect(@analytics).to receive(:track_event).with(
            'IdV: GPO verification submitted',
            **analytics_args,
          ).once
          analytics_args[:attempts] = 2
          expect(@analytics).to receive(:track_event).with(
            'IdV: GPO verification submitted',
            **analytics_args,
          ).once

          expect(@analytics).to receive(:track_event).with(
            'Rate Limit Reached',
            limiter_type: :verify_gpo_key,
          ).once

          expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_rate_limited).once

          max_attempts.times do |i|
            post(
              :create,
              params: {
                gpo_verify_form: {
                  otp: invalid_otp,
                },
              },
            )
          end

          post(
            :create,
            params: {
              gpo_verify_form: {
                otp: submitted_otp,
              },
            },
          )

          expect(response).to render_template('idv/gpo_verify/rate_limited')
        end
      end

      context 'valid code is submitted' do
        it 'redirects to personal key page' do
          expect(@analytics).to receive(:track_event).with(
            'IdV: GPO verification submitted',
            success: false,
            errors: otp_code_error_message,
            pending_in_person_enrollment: false,
            fraud_check_failed: false,
            enqueued_at: nil,
            which_letter: nil,
            letter_count: 1,
            attempts: 1,
            error_details: otp_code_incorrect,
            pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
          ).exactly(max_attempts - 1).times
          expect(@analytics).to receive(:track_event).with(
            'IdV: GPO verification submitted',
            success: true,
            errors: {},
            pending_in_person_enrollment: false,
            fraud_check_failed: false,
            enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
            which_letter: 1,
            letter_count: 1,
            attempts: 2,
            pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
          ).once
          expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_submitted).
            exactly(max_attempts).times

          (max_attempts - 1).times do |i|
            post(
              :create,
              params: {
                gpo_verify_form: {
                  otp: invalid_otp,
                },
              },
            )
          end

          post(
            :create,
            params: {
              gpo_verify_form: {
                otp: submitted_otp,
              },
            },
          )

          expect(response).to redirect_to(idv_personal_key_url)
        end
      end
    end
  end
end
