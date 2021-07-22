require 'rails_helper'

describe Idv::PhoneController do
  include IdvHelper

  let(:max_attempts) { idv_max_attempts }
  let(:good_phone) { '+1 (703) 555-0000' }
  let(:bad_phone) do
    Proofing::Mock::AddressMockClient::UNVERIFIABLE_PHONE_NUMBER
  end
  let(:normalized_phone) { '7035550000' }
  let(:bad_phone) { '+1 (703) 555-5555' }

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_session_started,
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
      build(
        :user, :with_phone,
        with: { phone: good_phone, confirmed_at: Time.zone.now }
      )
    end

    before do
      stub_verify_steps_one_and_two(user)
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

    it 'redirects to fail when step attempts are exceeded' do
      subject.idv_session.step_attempts[:phone] = max_attempts

      get :new

      expect(response).to redirect_to idv_phone_errors_failure_url
    end

    it 'shows phone form if async process times out and allows successful resubmission' do
      stub_analytics
      allow(@analytics).to receive(:track_event)

      # setting the document capture session to a nonexistent uuid will trigger async
      # timed_out behavior
      subject.idv_session.idv_phone_step_document_capture_session_uuid = 'abc123'

      get :new
      expect(@analytics).to have_received(:track_event).with(Analytics::PROOFING_ADDRESS_TIMEOUT)
      expect(flash[:error]).to include t('idv.failure.timeout')
      expect(response).to render_template :new
      put :create, params: { idv_phone_form: { phone: good_phone } }
      get :new
      expect(response).to redirect_to idv_review_path
    end

    it 'shows waiting interstitial if async process is in progress' do
      # having a document capture session with PII but without results will trigger
      # in progress behavior
      document_capture_session = DocumentCaptureSession.create_by_user_id(
        user.id,
        @analytics,
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
      before do
        user = build(:user, :with_phone, with: { phone: '+1 (415) 555-0130' })
        stub_verify_steps_one_and_two(user)
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'renders #new' do
        put :create, params: { idv_phone_form: { phone: '703' } }

        expect(flash[:warning]).to be_nil
        expect(response).to render_template(:new)
      end

      it 'tracks form error and does not make a vendor API call' do
        expect_any_instance_of(Idv::Agent).to_not receive(:proof_address)

        put :create, params: { idv_phone_form: { phone: '703' } }

        result = {
          success: false,
          errors: {
            phone: [t('errors.messages.must_have_us_country_code')],
          },
          error_details: {
            phone: [:must_have_us_country_code],
          },
          country_code: nil,
          area_code: nil,
        }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_PHONE_CONFIRMATION_FORM, result
        )
        expect(subject.idv_session.vendor_phone_confirmation).to be_falsy
      end
    end

    context 'when form is valid' do
      before do
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'tracks event with valid phone' do
        user = build(:user, :with_phone, with: { phone: good_phone, confirmed_at: Time.zone.now })
        stub_verify_steps_one_and_two(user)

        put :create, params: { idv_phone_form: { phone: good_phone } }

        result = {
          success: true,
          errors: {},
          area_code: '703',
          country_code: 'US',
        }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_PHONE_CONFIRMATION_FORM, result
        )
      end

      context 'when same as user phone' do
        it 'redirects to review page and sets phone_confirmed_at' do
          user = build(
            :user, :with_phone, with: {
              phone: good_phone, confirmed_at: Time.zone.now
            }
          )
          stub_verify_steps_one_and_two(user)

          put :create, params: { idv_phone_form: { phone: good_phone } }

          expect(response).to redirect_to idv_phone_path
          get :new
          expect(response).to redirect_to idv_review_path

          expected_applicant = {
            'first_name' => 'Some',
            'last_name' => 'One',
            'phone' => normalized_phone,
            'uuid_prefix' => nil,
          }

          expect(subject.idv_session.applicant).to eq expected_applicant
          expect(subject.idv_session.vendor_phone_confirmation).to eq true
          expect(subject.idv_session.user_phone_confirmation).to eq true
        end
      end

      context 'when different phone from user phone' do
        it 'redirects to otp page and does not set phone_confirmed_at' do
          user = build(
            :user, :with_phone, with: {
              phone: '+1 (415) 555-0130', confirmed_at: Time.zone.now
            }
          )
          stub_verify_steps_one_and_two(user)

          put :create, params: { idv_phone_form: { phone: good_phone } }

          expect(response).to redirect_to idv_phone_path
          get :new
          expect(response).to redirect_to idv_otp_delivery_method_path

          expect(subject.idv_session.vendor_phone_confirmation).to eq true
          expect(subject.idv_session.user_phone_confirmation).to eq false
        end
      end

      it 'tracks event with valid phone' do
        user = build(:user, with: { phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now })
        stub_verify_steps_one_and_two(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        context = { stages: [{ address: 'AddressMock' }] }
        result = {
          success: true,
          errors: {},
          vendor: {
            messages: [],
            context: context,
            exception: nil,
            timed_out: false,
            transaction_id: 'address-mock-transaction-id-123',
          },
        }

        expect(@analytics).to receive(:track_event).ordered.with(
          Analytics::IDV_PHONE_CONFIRMATION_FORM, hash_including(:success)
        )
        expect(@analytics).to receive(:track_event).ordered.with(
          Analytics::IDV_PHONE_CONFIRMATION_VENDOR, result
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
        user = build(:user, with: { phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now })
        stub_verify_steps_one_and_two(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        context = { stages: [{ address: 'AddressMock' }] }
        result = {
          success: false,
          errors: {
            phone: ['The phone number could not be verified.'],
          },
          vendor: {
            messages: [],
            context: context,
            exception: nil,
            timed_out: false,
            transaction_id: 'address-mock-transaction-id-123',
          },
        }

        expect(@analytics).to receive(:track_event).ordered.with(
          Analytics::IDV_PHONE_CONFIRMATION_FORM, hash_including(:success)
        )

        put :create, params: { idv_phone_form: { phone: bad_phone } }

        expect(@analytics).to receive(:track_event).ordered.with(
          Analytics::IDV_PHONE_CONFIRMATION_VENDOR, result
        )
        expect(response).to redirect_to idv_phone_path

        get :new
      end
    end
  end
end
