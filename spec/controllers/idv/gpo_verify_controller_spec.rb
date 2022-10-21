require 'rails_helper'

RSpec.describe Idv::GpoVerifyController do
  let(:has_pending_profile) { true }
  let(:success) { true }
  let(:otp) { 'ABC123' }
  let(:submitted_otp) { otp }
  let(:pending_profile) do
    create(
      :profile,
      :with_pii,
      user: user,
      proofing_components: proofing_components,
    )
  end
  let(:proofing_components) { nil }
  let(:user) { create(:user) }

  before do
    stub_analytics
    stub_attempts_tracker
    stub_sign_in(user)
    decorated_user = stub_decorated_user_with_pending_profile(user)
    create(
      :gpo_confirmation_code,
      profile: pending_profile,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
    )
    allow(decorated_user).to receive(:pending_profile_requires_verification?).
      and_return(has_pending_profile)
  end

  describe '#index' do
    subject(:action) do
      get(:index)
    end

    context 'user has pending profile' do
      it 'renders page' do
        expect(@analytics).to receive(:track_event).with('IdV: GPO verification visited')

        action

        expect(response).to render_template('idv/gpo_verify/index')
      end

      it 'shows throttled page is user is throttled' do
        Throttle.new(throttle_type: :verify_gpo_key, user: user).increment_to_throttled!

        action

        expect(response).to render_template(:throttled)
      end
    end

    context 'user does not have pending profile' do
      let(:has_pending_profile) { false }

      it 'redirects to account page' do
        action

        expect(response).to redirect_to(account_url)
      end
    end

    context 'with throttle reached' do
      before do
        Throttle.new(throttle_type: :verify_gpo_key, user: user).increment_to_throttled!
      end

      it 'renders throttled page' do
        expect(@analytics).to receive(:track_event).with(
          'IdV: GPO verification visited',
        ).once
        expect(@analytics).to receive(:track_event).with(
          'Throttler Rate Limit Triggered',
          throttle_type: :verify_gpo_key,
        ).once

        action

        expect(response).to render_template(:throttled)
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
          enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
          pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        )
        expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_submitted).
          with(success_properties)

        action

        disavowal_event_count = user.events.where(event_type: :account_verified, ip: '0.0.0.0').
          where.not(disavowal_token_fingerprint: nil).count
        expect(disavowal_event_count).to eq 1
        expect(response).to redirect_to(sign_up_completed_url)
      end

      it 'dispatches account verified alert' do
        expect(UserAlerts::AlertUserAboutAccountVerified).to receive(:call)

        action
      end

      context 'with establishing in person enrollment' do
        let(:proofing_components) do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        end

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(controller).to receive(:pii).
            and_return(user.pending_profile.decrypt_pii(user.password).to_h)
        end

        it 'redirects to ready to verify screen' do
          expect(@analytics).to receive(:track_event).with(
            'IdV: GPO verification submitted',
            success: true,
            errors: {},
            pending_in_person_enrollment: true,
            enqueued_at: user.pending_profile.gpo_confirmation_codes.last.code_sent_at,
            pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
          )
          expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_submitted).
            with(success_properties)

          action

          expect(response).to redirect_to(idv_in_person_ready_to_verify_url)
        end

        it 'does not dispatch account verified alert' do
          expect(UserAlerts::AlertUserAboutAccountVerified).not_to receive(:call)

          action
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
          enqueued_at: nil,
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

    context 'with throttle reached' do
      let(:submitted_otp) { 'a-wrong-otp' }

      it 'renders the index page to show errors' do
        max_attempts = IdentityConfig.store.verify_gpo_key_max_attempts

        expect(@analytics).to receive(:track_event).with(
          'IdV: GPO verification submitted',
          success: false,
          errors: otp_code_error_message,
          pending_in_person_enrollment: false,
          enqueued_at: nil,
          error_details: otp_code_incorrect,
          pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        ).exactly(max_attempts).times

        expect(@analytics).to receive(:track_event).with(
          'Throttler Rate Limit Triggered',
          throttle_type: :verify_gpo_key,
        ).once

        expect(@irs_attempts_api_tracker).to receive(:idv_gpo_verification_rate_limited).once

        (max_attempts + 1).times do |i|
          post(
            :create,
            params: {
              gpo_verify_form: {
                otp: submitted_otp,
              },
            },
          )
        end

        expect(response).to render_template('idv/gpo_verify/throttled')
      end
    end
  end
end
