require 'rails_helper'

RSpec.describe Idv::OtpVerificationController do
  let(:user) { create(:user) }

  let(:phone) { '2255555000' }
  let(:vendor_phone_confirmation) { true }
  let(:user_phone_confirmation) { false }
  let(:phone_confirmation_otp_code) { '777777' }
  let(:phone_confirmation_otp_sent_at) { Time.zone.now }
  let(:delivery_method) { :sms }
  let(:user_phone_confirmation_session) do
    Idv::PhoneConfirmationSession.new(
      code: phone_confirmation_otp_code,
      phone: phone,
      delivery_method: delivery_method,
      user: user,
      sent_at: phone_confirmation_otp_sent_at,
    )
  end

  before do
    stub_analytics

    sign_in(user)
    stub_verify_steps_one_and_two(user)
    subject.idv_session.welcome_visited = true
    subject.idv_session.idv_consent_given_at = Time.zone.now
    subject.idv_session.flow_path = 'standard'
    subject.idv_session.pii_from_doc = Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT)
    subject.idv_session.threatmetrix_session_id = 'random-session-id'
    subject.idv_session.ssn = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE[:ssn]
    subject.idv_session.resolution_successful = true
    subject.idv_session.applicant[:phone] = phone
    subject.idv_session.address_verification_mechanism = 'phone'
    subject.idv_session.vendor_phone_confirmation = vendor_phone_confirmation
    subject.idv_session.user_phone_confirmation = user_phone_confirmation
    subject.idv_session.user_phone_confirmation_session = user_phone_confirmation_session
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::OtpVerificationController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSessionConcern' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  describe '#show' do
    context 'the user has not been sent an otp' do
      let(:user_phone_confirmation_session) { nil }
      let(:vendor_phone_confirmation) { nil }

      it 'redirects to the delivery method path' do
        get :show
        expect(response).to redirect_to(idv_phone_url)
      end
    end

    context 'the user has already confirmed their phone' do
      let(:user_phone_confirmation) { true }

      it 'allows the back button and renders show' do
        get :show
        expect(response).to render_template :show
      end
    end

    it 'tracks an analytics event' do
      get :show

      expect(@analytics).to have_logged_event('IdV: phone confirmation otp visited')
    end
  end

  describe '#update' do
    let(:otp_code_param) { { code: phone_confirmation_otp_code } }
    context 'the user has not been sent an otp' do
      let(:user_phone_confirmation_session) { nil }
      let(:vendor_phone_confirmation) { nil }

      it 'redirects to otp delivery method selection' do
        put :update, params: otp_code_param
        expect(response).to redirect_to(idv_phone_url)
      end
    end

    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update, params: otp_code_param
    end

    context 'the user has already confirmed their phone' do
      let(:user_phone_confirmation) { true }

      it 'redirects to the review step' do
        put :update, params: otp_code_param
        expect(response).to redirect_to(idv_enter_password_path)
      end
    end

    context 'the user is going through in person proofing' do
      before(:each) do
        create(:in_person_enrollment, :establishing, user: user)
        allow(IdentityConfig.store).to receive(:in_person_proofing_enabled)
          .and_return(true)
      end

      context 'the user uses sms otp' do
        it 'does not save the phone number if the feature flag is off' do
          put :update, params: otp_code_param

          phone_config = user.establishing_in_person_enrollment&.notification_phone_configuration
          expect(phone_config).to_not be_present
        end

        it 'saves the sms notification number to the enrollment' do
          expect(IdentityConfig.store).to receive(:in_person_send_proofing_notifications_enabled)
            .and_return(true)

          put :update, params: otp_code_param

          phone_config = user.establishing_in_person_enrollment&.notification_phone_configuration
          expect(phone_config).to be_present
          expect(phone_config.phone).to eq(phone)
        end
      end

      context 'the user uses voice otp' do
        let(:delivery_method) { :voice }

        it 'does not save the phone number if the feature flag is off' do
          put :update, params: otp_code_param

          phone_config = user.establishing_in_person_enrollment&.notification_phone_configuration
          expect(phone_config).to_not be_present
        end

        it 'does not save the sms notification number to the enrollment' do
          expect(IdentityConfig.store).to receive(:in_person_send_proofing_notifications_enabled)
            .and_return(true)

          put :update, params: otp_code_param

          phone_config = user.establishing_in_person_enrollment&.notification_phone_configuration
          expect(phone_config).to_not be_present
        end
      end
    end

    it 'tracks an analytics event' do
      put :update, params: otp_code_param

      expect(@analytics).to have_logged_event(
        'IdV: phone confirmation otp submitted',
        hash_including(
          success: true,
          code_expired: false,
          code_matches: true,
          otp_delivery_preference: :sms,
          second_factor_attempts_count: 0,
        ),
      )
    end
  end
end
