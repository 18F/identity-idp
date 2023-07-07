require 'rails_helper'

RSpec.describe Idv::PhoneController do
  include IdvHelper

  let(:max_attempts) { RateLimiter.max_attempts(:proof_address) }
  let(:good_phone) { '+1 (703) 555-0000' }
  let(:bad_phone) do
    Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER
  end
  let(:normalized_phone) { '7035550000' }
  let(:bad_phone) { '+1 (703) 555-5555' }
  let(:international_phone) { '+81 54 354 3643' }

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_verify_info_step_complete,
      )
    end

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_outage,
      )
    end
  end

  describe 'before_actions' do
    it 'includes before_actions from IdvSession' do
      expect(subject).to have_actions(:before, :redirect_if_sp_context_needed)
    end
  end

  describe '#new' do
    let(:user) do
      create(
        :user, :with_phone,
        with: { phone: good_phone, confirmed_at: Time.zone.now }
      )
    end

    before do
      stub_verify_steps_one_and_two(user)
    end

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

      it 'redirects to review when step is complete' do
        subject.idv_session.vendor_phone_confirmation = true
        get :new

        expect(response).to redirect_to idv_review_path
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

        allow(controller).to receive(:confirm_idv_applicant_created).and_call_original
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
        allow(@analytics).to receive(:track_event)
      end

      it 'logs an event showing that the user wants to choose a different number' do
        get :new, params: params

        expect(@analytics).to have_received(:track_event).with(
          'IdV: use different phone number',
          step: step,
          proofing_components: nil,
        )
      end
    end

    it 'shows phone form if async process times out and allows successful resubmission' do
      stub_analytics
      allow(@analytics).to receive(:track_event)

      # setting the document capture session to a nonexistent uuid will trigger async
      # missing behavior
      subject.idv_session.idv_phone_step_document_capture_session_uuid = 'abc123'

      get :new
      expect(@analytics).to have_received(:track_event).with('Proofing Address Result Missing')
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
  end

  describe '#create' do
    context 'when form is invalid' do
      let(:improbable_phone_error) do
        {
          phone: [:improbable_phone],
          otp_delivery_preference: [:inclusion],
        }
      end
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
        user = build(:user, :with_phone, with: { phone: '+1 (415) 555-0130' })
        stub_verify_steps_one_and_two(user)
        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)
      end

      it 'renders #new' do
        put :create, params: improbable_phone_form

        expect(flash[:error]).to eq improbable_phone_message
        expect(response).to render_template(:new)
      end

      it 'disallows non-US numbers' do
        put :create, params: { idv_phone_form: { phone: international_phone } }

        expect(flash[:error]).to eq improbable_phone_message
        expect(response).to render_template(:new)
      end

      it 'tracks form error events and does not make a vendor API call' do
        expect_any_instance_of(Idv::Agent).to_not receive(:proof_address)

        expect(@irs_attempts_api_tracker).to receive(:idv_phone_submitted).with(
          success: false,
          phone_number: improbable_phone_number,
          failure_reason: improbable_phone_error,
        )

        put :create, params: improbable_phone_form

        result = {
          success: false,
          errors: {
            phone: [improbable_phone_message],
            otp_delivery_preference: [improbable_otp_message],
          },
          error_details: improbable_phone_error,
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
          country_code: nil,
          area_code: nil,
          carrier: 'Test Mobile Carrier',
          phone_type: :mobile,
          otp_delivery_preference: '🎷',
          types: [],
          proofing_components: nil,
        }

        expect(@analytics).to have_received(:track_event).with(
          'IdV: phone confirmation form', result
        )
        expect(subject.idv_session.vendor_phone_confirmation).to be_falsy
      end
    end

    context 'when form is valid' do
      before do
        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)
      end

      it 'tracks events with valid phone' do
        user = build(:user, :with_phone, with: { phone: good_phone, confirmed_at: Time.zone.now })
        stub_verify_steps_one_and_two(user)

        expect(@irs_attempts_api_tracker).to receive(:idv_phone_submitted).with(
          success: true,
          phone_number: good_phone,
          failure_reason: nil,
        )

        phone_params = {
          idv_phone_form: {
            phone: good_phone,
            otp_delivery_preference: :sms,
          },
        }

        put :create, params: phone_params

        result = {
          success: true,
          errors: {},
          area_code: '703',
          country_code: 'US',
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
          carrier: 'Test Mobile Carrier',
          phone_type: :mobile,
          otp_delivery_preference: 'sms',
          types: [:fixed_or_mobile],
          proofing_components: nil,
        }

        expect(@analytics).to have_received(:track_event).with(
          'IdV: phone confirmation form', result
        )
      end

      it 'updates the doc auth log for the user with verify_phone_submit step' do
        user = create(:user, :with_phone, with: { phone: good_phone, confirmed_at: Time.zone.now })
        unstub_analytics
        stub_verify_steps_one_and_two(user)

        doc_auth_log = DocAuthLog.create(user_id: user.id)

        expect { put :create, params: { idv_phone_form: { phone: good_phone } } }.to(
          change { doc_auth_log.reload.verify_phone_submit_count }.from(0).to(1),
        )
      end

      context 'when same as user phone' do
        before do
          user = build(
            :user, :with_phone, with: {
              phone: good_phone, confirmed_at: Time.zone.now
            }
          )
          stub_verify_steps_one_and_two(user)
        end

        it 'redirects to otp delivery page' do
          original_applicant = subject.idv_session.applicant.dup

          put :create, params: {
            idv_phone_form: {
              phone: good_phone,
              otp_delivery_preference: 'sms',
            },
          }

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
        before do
          user = build(
            :user, :with_phone, with: {
              phone: '+1 (415) 555-0130', confirmed_at: Time.zone.now
            }
          )
          stub_verify_steps_one_and_two(user)
        end

        it 'redirects to otp page and does not set phone_confirmed_at' do
          put :create, params: {
            idv_phone_form: {
              phone: good_phone,
              otp_delivery_preference: 'sms',
            },
          }

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
        user = build(:user, with: { phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now })
        stub_verify_steps_one_and_two(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        result = {
          success: true,
          new_phone_added: true,
          errors: {},
          phone_fingerprint: Pii::Fingerprinter.fingerprint(proofing_phone.e164),
          country_code: proofing_phone.country,
          area_code: proofing_phone.area_code,
          pii_like_keypaths: [[:errors, :phone], [:context, :stages, :address]],
          vendor: {
            vendor_name: 'AddressMock',
            exception: nil,
            timed_out: false,
            transaction_id: 'address-mock-transaction-id-123',
            reference: '',
          },
          proofing_components: nil,
        }

        expect(@analytics).to receive(:track_event).ordered.with(
          'IdV: phone confirmation form', hash_including(:success)
        )
        expect(@analytics).to receive(:track_event).ordered.with(
          'IdV: phone confirmation vendor', result
        )

        put :create, params: { idv_phone_form: { phone: good_phone } }
        expect(response).to redirect_to idv_phone_path
        get :new
      end
    end

    context 'when verification fails' do
      it 'renders failure page and does not set phone confirmation' do
        user = build(:user, with: { phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now })
        stub_verify_steps_one_and_two(user)

        put :create, params: { idv_phone_form: { phone: bad_phone } }

        expect(response).to redirect_to idv_phone_path
        get :new
        expect(response).to redirect_to idv_phone_errors_warning_path

        expect(subject.idv_session.vendor_phone_confirmation).to be_falsy
        expect(subject.idv_session.user_phone_confirmation).to be_falsy
      end

      it 'tracks event with invalid phone' do
        proofing_phone = Phonelib.parse(bad_phone)
        user = build(:user, with: { phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now })
        stub_verify_steps_one_and_two(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        result = {
          success: false,
          new_phone_added: true,
          phone_fingerprint: Pii::Fingerprinter.fingerprint(proofing_phone.e164),
          country_code: proofing_phone.country,
          area_code: proofing_phone.area_code,
          errors: {
            phone: ['The phone number could not be verified.'],
          },
          pii_like_keypaths: [[:errors, :phone], [:context, :stages, :address]],
          vendor: {
            vendor_name: 'AddressMock',
            exception: nil,
            timed_out: false,
            transaction_id: 'address-mock-transaction-id-123',
            reference: '',
          },
          proofing_components: nil,
        }

        expect(@analytics).to receive(:track_event).ordered.with(
          'IdV: phone confirmation form', hash_including(:success)
        )

        put :create, params: { idv_phone_form: { phone: bad_phone } }

        expect(@analytics).to receive(:track_event).ordered.with(
          'IdV: phone confirmation vendor', result
        )
        expect(response).to redirect_to idv_phone_path

        get :new
      end

      context 'when the user is rate limited by submission' do
        before do
          stub_analytics

          user = create(:user, with: { phone: '+1 (415) 555-0130' })
          stub_verify_steps_one_and_two(user)

          rate_limiter = RateLimiter.new(rate_limit_type: :proof_address, user: user)
          rate_limiter.increment_to_limited!

          put :create, params: { idv_phone_form: { phone: bad_phone } }
        end

        it 'redirects to fail' do
          expect(response).to redirect_to idv_phone_errors_failure_url
        end

        it 'tracks rate limited event' do
          expect(@analytics).to have_logged_event(
            'Throttler Rate Limit Triggered',
            {
              throttle_type: :proof_address,
              step_name: :phone,
            },
          )
        end
      end
    end
  end
end
