require 'rails_helper'

RSpec.describe Idv::PhoneController, allowed_extra_analytics: [:*] do
  include FlowPolicyHelper

  let(:max_attempts) { RateLimiter.max_attempts(:proof_address) }
  let(:good_phone) { '+1 (703) 555-0000' }
  let(:bad_phone) do
    Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER
  end
  let(:normalized_phone) { '7035550000' }
  let(:bad_phone) { '+1 (703) 555-5555' }
  let(:international_phone) { '+81 54 354 3643' }
  let(:timeout_phone) { '7035555888' }

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::PhoneController.step_info).to be_valid
    end
  end

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_mail_only_outage,
      )
    end
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSessionConcern' do
      expect(subject).to have_actions(:before, :redirect_unless_sp_requested_verification)
    end
  end

  let(:user) do
    create(
      :user, :with_phone,
      with: { phone: good_phone, confirmed_at: Time.zone.now }
    )
  end

  before do
    stub_sign_in(user)
    stub_up_to(:verify_info, idv_session: subject.idv_session)
    stub_analytics
  end

  describe '#new' do
    it 'updates the doc auth log for the user for the usps_letter_sent event' do
      unstub_analytics
      doc_auth_log = DocAuthLog.create(user_id: user.id)

      expect { get :new }.to(
        change { doc_auth_log.reload.verify_phone_view_count }.from(0).to(1),
      )
    end

    context 'when the phone number has been confirmed as user 2FA phone' do
      before do
        subject.idv_session.user_phone_confirmation = true
      end

      it 'allows the back button and renders new' do
        subject.idv_session.vendor_phone_confirmation = true
        get :new

        expect(response).to render_template :new
      end
    end

    context 'when the phone number has not been confirmed as user 2FA phone' do
      before do
        subject.idv_session.user_phone_confirmation = nil
      end

      it 'renders the form' do
        subject.idv_session.vendor_phone_confirmation = true
        get :new

        expect(response).to render_template :new
      end
    end

    context 'when the user has not finished the verify step' do
      before do
        subject.idv_session.applicant = nil
        subject.idv_session.resolution_successful = nil
      end

      it 'redirects to the verify step' do
        get :new

        expect(response).to redirect_to idv_verify_info_url
      end
    end

    context 'when the user is rate limited' do
      before do
        RateLimiter.new(rate_limit_type: :proof_address, user: user).increment_to_limited!
      end

      it 'redirects to fail' do
        get :new

        expect(response).to redirect_to idv_phone_errors_failure_url
      end
    end

    context 'when the user has chosen to use a different number' do
      let(:step) { 'path_where_user_asked_to_use_different_number' }
      let(:params) { { step: step } }

      before do
        stub_analytics
      end

      it 'logs an event showing that the user wants to choose a different number' do
        get :new, params: params

        expect(@analytics).to have_logged_event(
          'IdV: use different phone number',
          step: step,
          proofing_components: nil,
        )
      end
    end

    it 'shows phone form if async process times out and allows successful resubmission' do
      stub_analytics

      # setting the document capture session to a nonexistent uuid will trigger async
      # missing behavior
      subject.idv_session.idv_phone_step_document_capture_session_uuid = 'abc123'

      get :new
      expect(@analytics).to have_logged_event('Proofing Address Result Missing')
      expect(flash[:error]).to include t('idv.failure.timeout')
      expect(response).to render_template :new
      put :create, params: { idv_phone_form: { phone: good_phone, otp_delivery_preference: :sms } }
      get :new
      expect(response).to redirect_to idv_otp_verification_path
    end

    it 'shows waiting interstitial if async process is in progress' do
      # having a document capture session with PII but without results will trigger
      # in progress behavior
      document_capture_session = DocumentCaptureSession.create(
        user_id: user.id,
        requested_at: Time.zone.now,
      )
      document_capture_session.create_proofing_session

      subject.idv_session.idv_phone_step_document_capture_session_uuid =
        document_capture_session.uuid

      get :new
      expect(response).to render_template :wait
    end

    context 'when the document capture session has a doc auth result' do
      let(:phone) { '2025555555' }

      before do
        subject.idv_session.previous_phone_step_params = {
          phone: phone, international_code: 'US', otp_delivery_preference: 'sms'
        }
        document_capture_session = DocumentCaptureSession.create(
          user_id: user.id,
          requested_at: Time.zone.now,
        )
        document_capture_session.create_proofing_session
        subject.idv_session.idv_phone_step_document_capture_session_uuid =
          document_capture_session.uuid
        proofing_result = Proofing::Mock::AddressMockClient.new.proof(phone: phone)
        document_capture_session.store_proofing_result(proofing_result)
      end

      context 'when the result is successful' do
        it 'sends an OTP and redirects to OTP confirmation' do
          get :new

          expect(response).to redirect_to(idv_otp_verification_url)
          expect(subject.idv_session.vendor_phone_confirmation).to eq(true)
          expect(subject.idv_session.user_phone_confirmation).to eq(false)
          expect(Telephony::Test::Message.messages.length).to eq(1)
        end

        context 'the user submited their last attempt' do
          it 'redirects to the OTP confirmation and the rate limiter is maxed' do
            RateLimiter.new(user: user, rate_limit_type: :proof_address).increment_to_limited!

            get :new

            expect(response).to redirect_to(idv_otp_verification_url)
            expect(Telephony::Test::Message.messages.length).to eq(1)
            expect(RateLimiter.new(user: user, rate_limit_type: :proof_address).maxed?).to eq(true)
          end
        end
      end

      context 'when the doc auth result is not successful' do
        # This is a test phone number that causes the mock proofer to fail
        let(:phone) { Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER }

        it 'does not send an otp and redirects to the error page' do
          get :new

          expect(response).to redirect_to(idv_phone_errors_warning_url)
          expect(subject.idv_session.vendor_phone_confirmation).to eq(nil)
          expect(subject.idv_session.user_phone_confirmation).to eq(nil)
          expect(Telephony::Test::Message.messages.length).to eq(0)
        end

        context 'the user submited their last attempt' do
          it 'it redirects to the failure page and the rate limiter is maxed' do
            RateLimiter.new(user: user, rate_limit_type: :proof_address).increment_to_limited!

            get :new

            expect(response).to redirect_to(idv_phone_errors_failure_url)
            expect(Telephony::Test::Message.messages.length).to eq(0)
            expect(RateLimiter.new(user: user, rate_limit_type: :proof_address).maxed?).to eq(true)
          end
        end
      end
    end
  end

  describe '#create' do
    let(:user) do
      create(
        :user, :with_phone,
        with: { phone: '+1 (415) 555-0130' }
      )
    end
    let(:ab_test_args) do
      { sample_bucket1: :sample_value1, sample_bucket2: :sample_value2 }
    end

    before do
      allow(subject).to receive(:ab_test_analytics_buckets).and_return(ab_test_args)
    end
    context 'when form is invalid' do
      let(:improbable_phone_message) { t('errors.messages.improbable_phone') }
      let(:improbable_otp_message) { 'is not included in the list' }
      let(:improbable_phone_number) { '703' }
      let(:improbable_phone_form) do
        {
          idv_phone_form:
            {
              phone: improbable_phone_number,
              otp_delivery_preference: :🎷,
            },
        }
      end
      before do
      end

      it 'renders #new' do
        put :create, params: improbable_phone_form

        expect(flash[:error]).to eq improbable_phone_message
        expect(response).to render_template(:new)
      end

      it 'invalidates phone step in idv_session' do
        subject.idv_session.vendor_phone_confirmation = true
        subject.idv_session.user_phone_confirmation = true

        put :create, params: improbable_phone_form

        expect(subject.idv_session.vendor_phone_confirmation).to be_nil
        expect(subject.idv_session.user_phone_confirmation).to be_nil
      end

      it 'disallows non-US numbers' do
        put :create, params: { idv_phone_form: { phone: international_phone } }

        expect(flash[:error]).to eq improbable_phone_message
        expect(response).to render_template(:new)
      end

      it 'tracks form error events and does not make a vendor API call' do
        expect_any_instance_of(Idv::Agent).to_not receive(:proof_address)

        put :create, params: improbable_phone_form

        result = {
          success: false,
          errors: {
            phone: [improbable_phone_message],
            otp_delivery_preference: [improbable_otp_message],
          },
          error_details: {
            phone: { improbable_phone: true },
            otp_delivery_preference: { inclusion: true },
          },
          country_code: nil,
          area_code: nil,
          carrier: 'Test Mobile Carrier',
          phone_type: :mobile,
          otp_delivery_preference: '🎷',
          types: [],
          **ab_test_args,
        }

        expect(@analytics).to have_logged_event(
          'IdV: phone confirmation form',
          hash_including(result),
        )

        expect(subject.idv_session.vendor_phone_confirmation).to be_falsy
      end
    end

    context 'when form is valid' do
      let(:phone_params) do
        { idv_phone_form: {
          phone: good_phone,
          otp_delivery_preference: :sms,
        } }
      end

      it 'invalidates future steps and invalidates phone step' do
        subject.idv_session.vendor_phone_confirmation = true
        subject.idv_session.user_phone_confirmation = true

        expect(subject).to receive(:clear_future_steps!)

        put :create, params: phone_params

        expect(subject.idv_session.vendor_phone_confirmation).to be_nil
        expect(subject.idv_session.user_phone_confirmation).to be_nil
      end

      it 'tracks events with valid phone' do
        put :create, params: phone_params

        result = {
          success: true,
          errors: {},
          error_details: nil,
          area_code: '703',
          country_code: 'US',
          carrier: 'Test Mobile Carrier',
          phone_type: :mobile,
          otp_delivery_preference: 'sms',
          types: [:fixed_or_mobile],
          **ab_test_args,
        }

        expect(@analytics).to have_logged_event(
          'IdV: phone confirmation form',
          hash_including(result),
        )
      end

      it 'updates the doc auth log for the user with verify_phone_submit step' do
        doc_auth_log = DocAuthLog.create(user_id: user.id)

        expect { put :create, params: { idv_phone_form: { phone: good_phone } } }.to(
          change { doc_auth_log.reload.verify_phone_submit_count }.from(0).to(1),
        )
      end

      context 'when same as user phone' do
        it 'redirects to otp delivery page' do
          original_applicant = subject.idv_session.applicant.dup

          put :create, params: phone_params

          expect(response).to redirect_to idv_phone_path
          get :new
          expect(response).to redirect_to idv_otp_verification_path

          expect(subject.idv_session.applicant).to eq(
            original_applicant.merge(
              'phone' => normalized_phone,
              'uuid_prefix' => nil,
            ),
          )
          expect(subject.idv_session.vendor_phone_confirmation).to eq true
          expect(subject.idv_session.user_phone_confirmation).to eq false
          expect(subject.idv_session.failed_phone_step_numbers).to be_empty
        end

        context 'with full vendor outage' do
          before do
            allow_any_instance_of(OutageStatus).to receive(:all_phone_vendor_outage?).
              and_return(true)
          end

          it 'redirects to vendor outage page' do
            put :create, params: { idv_phone_form: { phone: good_phone } }

            expect(response).to redirect_to idv_phone_path
            get :new
            expect(response).to redirect_to vendor_outage_path(from: :idv_phone)
          end
        end
      end

      context 'when different phone from user phone' do
        it 'redirects to otp page and does not set phone_confirmed_at' do
          put :create, params: phone_params

          expect(response).to redirect_to idv_phone_path
          get :new
          expect(response).to redirect_to idv_otp_verification_path

          expect(subject.idv_session.vendor_phone_confirmation).to eq true
          expect(subject.idv_session.user_phone_confirmation).to eq false
        end

        context 'with full vendor outage' do
          before do
            allow_any_instance_of(OutageStatus).to receive(:all_phone_vendor_outage?).
              and_return(true)
          end

          it 'redirects to vendor outage page' do
            put :create, params: { idv_phone_form: { phone: good_phone } }

            expect(response).to redirect_to idv_phone_path
            get :new
            expect(response).to redirect_to vendor_outage_path(from: :idv_phone)
          end
        end
      end

      it 'tracks event with valid phone' do
        proofing_phone = Phonelib.parse(good_phone)

        result = {
          success: true,
          new_phone_added: true,
          hybrid_handoff_phone_used: false,
          errors: {},
          error_details: nil,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(proofing_phone.e164),
          country_code: proofing_phone.country,
          area_code: proofing_phone.area_code,
          vendor: {
            vendor_name: 'AddressMock',
            exception: nil,
            timed_out: false,
            transaction_id: 'address-mock-transaction-id-123',
            reference: '',
          },
        }

        put :create, params: { idv_phone_form: { phone: good_phone } }

        expect(@analytics).to have_logged_event(
          'IdV: phone confirmation form',
          hash_including(:success),
        )

        expect(response).to redirect_to idv_phone_path

        get :new

        expect(@analytics).to have_logged_event(
          'IdV: phone confirmation vendor',
          hash_including(result),
        )
      end
    end

    it 'tracks that the hybrid handoff phone was used' do
      subject.idv_session.phone_for_mobile_flow = good_phone

      put :create, params: { idv_phone_form: { phone: good_phone } }
      expect(response).to redirect_to idv_phone_path

      expect(@analytics).to have_logged_event(
        'IdV: phone confirmation form',
        hash_including(:success),
      )

      get :new

      expect(@analytics).to have_logged_event(
        'IdV: phone confirmation vendor',
        hash_including(hybrid_handoff_phone_used: true),
      )
    end

    context 'when verification fails' do
      it 'renders failure page and does not set phone confirmation' do
        put :create, params: { idv_phone_form: { phone: bad_phone } }

        expect(response).to redirect_to idv_phone_path
        get :new
        expect(response).to redirect_to idv_phone_errors_warning_path

        expect(subject.idv_session.vendor_phone_confirmation).to be_falsy
        expect(subject.idv_session.user_phone_confirmation).to be_falsy
        expect(subject.idv_session.failed_phone_step_numbers).to contain_exactly('+17035555555')
      end

      it 'renders timeout page and does not set phone confirmation' do
        put :create, params: { idv_phone_form: { phone: timeout_phone } }

        expect(response).to redirect_to idv_phone_path
        get :new
        expect(response).to redirect_to idv_phone_errors_timeout_path

        expect(subject.idv_session.vendor_phone_confirmation).to be_falsy
        expect(subject.idv_session.user_phone_confirmation).to be_falsy
        expect(subject.idv_session.failed_phone_step_numbers).to be_empty
      end

      it 'tracks event with invalid phone' do
        proofing_phone = Phonelib.parse(bad_phone)

        result = {
          success: false,
          new_phone_added: true,
          hybrid_handoff_phone_used: false,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(proofing_phone.e164),
          country_code: proofing_phone.country,
          area_code: proofing_phone.area_code,
          errors: {
            phone: ['The phone number could not be verified.'],
          },
          vendor: {
            vendor_name: 'AddressMock',
            exception: nil,
            timed_out: false,
            transaction_id: 'address-mock-transaction-id-123',
            reference: '',
          },
          proofing_components: nil,
        }

        put :create, params: { idv_phone_form: { phone: bad_phone } }

        expect(@analytics).to have_logged_event(
          'IdV: phone confirmation form',
          hash_including(:success),
        )

        expect(response).to redirect_to idv_phone_path

        get :new

        expect(@analytics).to have_logged_event(
          'IdV: phone confirmation vendor',
          hash_including(result),
        )
      end

      context 'when the user is rate limited by submission' do
        before do
          stub_analytics

          rate_limiter = RateLimiter.new(rate_limit_type: :proof_address, user: user)
          rate_limiter.increment_to_limited!

          put :create, params: { idv_phone_form: { phone: bad_phone } }
        end

        it 'redirects to fail' do
          expect(response).to redirect_to idv_phone_errors_failure_url
        end

        it 'tracks rate limited event' do
          expect(@analytics).to have_logged_event(
            'Rate Limit Reached',
            limiter_type: :proof_address,
          )
        end
      end
    end
  end
end
