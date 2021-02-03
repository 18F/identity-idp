require 'rails_helper'

RSpec.describe Users::VerifyAccountController do
  let(:has_pending_profile) { true }
  let(:success) { true }
  let(:otp) { 'ABC123' }
  let(:submitted_otp) { otp }
  let(:pending_profile) { build(:profile) }
  let(:current_user) { create(:user, password: ControllerHelper::VALID_PASSWORD) }

  before do
    stub_analytics
    user = stub_sign_in(current_user)
    decorated_user = stub_decorated_user_with_pending_profile(user)
    create(
      :usps_confirmation_code,
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
      render_views
      it 'renders page with a link to send a letter' do
        expect(@analytics).to receive(:track_event).with(Analytics::ACCOUNT_VERIFICATION_VISITED)

        action

        expect(response).to render_template('users/verify_account/index')
        expect(response.body).to include(t('idv.messages.usps.resend'))
      end
    end

    context 'user does not have pending profile' do
      let(:has_pending_profile) { false }

      it 'redirects to account page' do
        action

        expect(response).to redirect_to(account_url)
      end
    end

    context 'user is throttled from sending letters' do
      render_views
      before do
        AppConfig.env.idv_send_letter_max_attempts.to_i.times do
          Throttler::IsThrottledElseIncrement.call(current_user.id, :idv_send_letter)
        end
      end

      it 'does not contain a link to send a letter' do
        action

        expect(response).to render_template('users/verify_account/index')
        expect(response.body).to_not include(t('idv.messages.usps.resend'))
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
          success: true, errors: {},
        )

        action

        expect(response).to redirect_to(sign_up_completed_url)
      end
    end

    context 'with an invalid form' do
      let(:submitted_otp) { 'the-wrong-otp' }

      it 'renders the index page to show errors' do
        expect(@analytics).to receive(:track_event).with(
          Analytics::ACCOUNT_VERIFICATION_SUBMITTED,
          success: false, errors: { otp: [t('errors.messages.confirmation_code_incorrect')]},
        )

        action

        expect(response).to render_template('users/verify_account/index')
      end
    end
  end
end
