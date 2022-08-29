require 'rails_helper'

describe Idv::PhoneController do
  include IdvHelper

  let(:max_attempts) { Throttle.max_attempts(:proof_address) }
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
      create(
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

    context 'when the user is throttled' do
      before do
        Throttle.new(throttle_type: :proof_address, user: user).increment_to_throttled!
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

        expect(@analytics).to have_received(:track_event).
          with('IdV: use different phone number', step: step)
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
      put :create, params: { idv_phone_form: { phone: good_phone } }
      get :new
      expect(response).to redirect_to idv_otp_delivery_method_path
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
      before do
        user = build(:user, :with_phone, with: { phone: '+1 (415) 555-0130' })
        stub_verify_steps_one_and_two(user)
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'renders #new' do
        put :create, params: { idv_phone_form: { phone: '703' } }

        expect(flash[:error]).to eq t('errors.messages.must_have_us_country_code')
        expect(response).to render_template(:new)
      end

      it 'disallows non-US numbers' do
        put :create, params: { idv_phone_form: { phone: international_phone } }

        expect(flash[:error]).to eq t('errors.messages.must_have_us_country_code')
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
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
          country_code: nil,
          area_code: nil,
          carrier: 'Test Mobile Carrier',
          phone_type: :mobile,
          types: [],
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
          pii_like_keypaths: [[:errors, :phone], [:error_details, :phone]],
          carrier: 'Test Mobile Carrier',
          phone_type: :mobile,
          types: [:fixed_or_mobile],
        }

        expect(@analytics).to have_received(:track_event).with(
          'IdV: phone confirmation form', result
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

          put :create, params: { idv_phone_form: { phone: good_phone } }

          expect(response).to redirect_to idv_phone_path
          get :new
          expect(response).to redirect_to idv_otp_delivery_method_path

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
            allow_any_instance_of(VendorStatus).to receive(:all_phone_vendor_outage?).
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
          put :create, params: { idv_phone_form: { phone: good_phone } }

          expect(response).to redirect_to idv_phone_path
          get :new
          expect(response).to redirect_to idv_otp_delivery_method_path

          expect(subject.idv_session.vendor_phone_confirmation).to eq true
          expect(subject.idv_session.user_phone_confirmation).to eq false
        end

        context 'with full vendor outage' do
          before do
            allow_any_instance_of(VendorStatus).to receive(:all_phone_vendor_outage?).
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
        user = build(:user, with: { phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now })
        stub_verify_steps_one_and_two(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        context = { stages: [{ address: 'AddressMock' }] }
        result = {
          success: true,
          new_phone_added: true,
          errors: {},
          pii_like_keypaths: [[:errors, :phone], [:context, :stages, :address]],
          vendor: {
            messages: [],
            context: context,
            exception: nil,
            timed_out: false,
            transaction_id: 'address-mock-transaction-id-123',
          },
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
        user = build(:user, with: { phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now })
        stub_verify_steps_one_and_two(user)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        context = { stages: [{ address: 'AddressMock' }] }
        result = {
          success: false,
          new_phone_added: true,
          errors: {
            phone: ['The phone number could not be verified.'],
          },
          pii_like_keypaths: [[:errors, :phone], [:context, :stages, :address]],
          vendor: {
            messages: [],
            context: context,
            exception: nil,
            timed_out: false,
            transaction_id: 'address-mock-transaction-id-123',
          },
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

      context 'when the user is throttled by submission' do
        before do
          user = create(:user, with: { phone: '+1 (415) 555-0130' })
          stub_verify_steps_one_and_two(user)
          throttle = Throttle.new(throttle_type: :proof_address, user: user)
          (max_attempts - 1).times do
            throttle.increment!
          end
        end

        it 'tracks throttled event' do
          stub_analytics
          allow(@analytics).to receive(:track_event)

          expect(@analytics).to receive(:track_event).with(
            'Throttler Rate Limit Triggered',
            {
              throttle_type: :proof_address,
              step_name: :phone,
            },
          )

          put :create, params: { idv_phone_form: { phone: bad_phone } }
          get :new
        end
      end
    end
  end
end
