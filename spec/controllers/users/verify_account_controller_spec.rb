require 'rails_helper'

RSpec.describe Users::VerifyAccountController do
  let(:has_pending_profile) { true }
  let(:success) { true }
  let(:otp) { 'ABC123' }
  let(:submitted_otp) { otp }
  let(:pending_profile) { build(:profile) }
  let(:user) { create(:user) }

  before do
    stub_analytics
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
        expect(@analytics).to receive(:track_event).with(Analytics::ACCOUNT_VERIFICATION_VISITED)

        action

        expect(response).to render_template('users/verify_account/index')
      end

      it 'shows throttled page is user is throttled' do
        create(:throttle, :with_throttled, user: user, throttle_type: :verify_gpo_key)

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
        create(:throttle, :with_throttled, user: user, throttle_type: :verify_gpo_key)
      end

      it 'renders throttled page' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with(
          Analytics::ACCOUNT_VERIFICATION_VISITED,
        ).once
        expect(@analytics).to receive(:track_event).with(
          Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
          throttle_type: :verify_gpo_key,
        ).once

        action

        expect(response).to render_template(:throttled)
      end
    end
  end

  describe '#create' do
    subject(:action) do
      post(
        :create,
        params: {
          verify_account_form: {
            otp: submitted_otp,
          },
        },
      )
    end

    context 'with a valid form' do
      let(:success) { true }

      it 'redirects to the sign_up/completions page' do
        expect(@analytics).to receive(:track_event).with(
          Analytics::ACCOUNT_VERIFICATION_SUBMITTED,
          success: true,
          errors: {},
          pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        )

        action

        disavowal_event_count = user.events.where(event_type: :account_verified, ip: '0.0.0.0').
          where.not(disavowal_token_fingerprint: nil).count
        expect(disavowal_event_count).to eq 1
        expect(response).to redirect_to(sign_up_completed_url)
      end
    end

    context 'with an invalid form' do
      let(:submitted_otp) { 'the-wrong-otp' }

      it 'redirects to the index page to show errors' do
        expect(@analytics).to receive(:track_event).with(
          Analytics::ACCOUNT_VERIFICATION_SUBMITTED,
          success: false,
          errors: { otp: [t('errors.messages.confirmation_code_incorrect')]},
          error_details: { otp: [:confirmation_code_incorrect]},
          pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        )

        action

        expect(response).to redirect_to(verify_account_url)
      end
    end

    context 'with throttle reached' do
      let(:submitted_otp) { 'a-wrong-otp' }

      it 'renders the index page to show errors' do
        max_attempts = IdentityConfig.store.verify_gpo_key_max_attempts

        expect(@analytics).to receive(:track_event).with(
          Analytics::ACCOUNT_VERIFICATION_SUBMITTED,
          success: false,
          errors: { otp: [t('errors.messages.confirmation_code_incorrect')]},
          error_details: { otp: [:confirmation_code_incorrect]},
          pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        ).exactly(max_attempts).times

        expect(@analytics).to receive(:track_event).with(
          Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
          throttle_type: :verify_gpo_key,
        ).once

        (max_attempts + 1).times do |i|
          post(
            :create,
            params: {
              verify_account_form: {
                otp: submitted_otp,
              },
            },
          )
        end

        expect(response).to render_template('users/verify_account/throttled')
      end
    end
  end
end
