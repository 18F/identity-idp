require 'rails_helper'

describe Idv::PhoneController do
  include Features::LocalizationHelper
  include IdvHelper

  let(:max_attempts) { Idv::Attempter.idv_max_attempts }
  let(:good_phone) { '+1 (703) 555-0000' }
  let(:normalized_phone) { '7035550000' }
  let(:bad_phone) { '+1 (703) 555-5555' }

  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_session_started
      )
    end
  end

  describe '#new' do
    let(:user) { build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now) }

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

      expect(response).to redirect_to idv_phone_failure_url(:fail)
    end
  end

  describe '#create' do
    context 'when form is invalid' do
      before do
        user = build(:user, phone: '+1 (415) 555-0130')
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
        expect(Idv::Proofer).to_not receive(:get_vendor)

        put :create, params: { idv_phone_form: { phone: '703' } }

        result = {
          success: false,
          errors: {
            phone: [t('errors.messages.must_have_us_country_code')],
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
        user = build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now)
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
    end

    context 'when verification succeeds' do
      context 'with same phone as user phone' do
        it 'redirects to review page and sets phone confirmation' do
          user = build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now)
          stub_verify_steps_one_and_two(user)

          put :create, params: { idv_phone_form: { phone: good_phone } }

          expect(response).to redirect_to idv_review_path

          expected_applicant = {
            first_name: 'Some',
            last_name: 'One',
            phone: normalized_phone,
          }.with_indifferent_access

          expect(subject.idv_session.applicant).to eq expected_applicant
          expect(subject.idv_session.vendor_phone_confirmation).to eq true
          expect(subject.idv_session.user_phone_confirmation).to eq true
        end
      end

      context 'with different phone from user phone' do
        it 'redirects to otp page and does not set phone confirmation' do
          user = build(:user, phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now)
          stub_verify_steps_one_and_two(user)

          put :create, params: { idv_phone_form: { phone: good_phone } }

          expect(response).to redirect_to idv_otp_delivery_method_path

          expect(subject.idv_session.vendor_phone_confirmation).to eq true
          expect(subject.idv_session.user_phone_confirmation).to eq false
        end
      end
    end

    context 'when verification fails' do
      it 'renders failure page and does not set phone confirmation' do
        user = build(:user, phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now)
        stub_verify_steps_one_and_two(user)

        put :create, params: { idv_phone_form: { phone: '7035555555' } }

        expect(response).to redirect_to idv_phone_failure_path(reason: :warning)

        expect(subject.idv_session.vendor_phone_confirmation).to be_falsy
        expect(subject.idv_session.user_phone_confirmation).to be_falsy
      end
    end

    # context 'when ' do
    #   let(:result_id) { SecureRandom.uuid }
    #
    #   before do
    #     controller.idv_session.async_result_id = result_id
    #     VendorValidatorResultStorage.new.store(result_id: result_id, result: result)
    #   end
    #
    #   let(:result) { Idv::VendorResult.new(success: true) }
    #
    #   context 'when the phone is verified' do
    #     let(:result) do
    #       Idv::VendorResult.new(
    #         success: false,
    #         errors: { phone: ['The phone number could not be verified.'] }
    #       )
    #     end
    #
    #     let(:params) { { phone: bad_phone } }
    #     let(:user) { build(:user, phone: bad_phone, phone_confirmed_at: Time.zone.now) }
    #
    #     it 'tracks event with invalid phone' do
    #       stub_analytics
    #       allow(@analytics).to receive(:track_event)
    #
    #       get :show
    #
    #       result = {
    #         success: false,
    #         errors: {
    #           phone: ['The phone number could not be verified.'],
    #         },
    #         vendor: { messages: [], context: {}, exception: nil },
    #       }
    #
    #       expect(response).to redirect_to idv_phone_failure_path(:warning)
    #       expect(@analytics).to have_received(:track_event).with(
    #         Analytics::IDV_PHONE_CONFIRMATION_VENDOR, result
    #       )
    #     end
    #   end
    #
    #   context 'attempt window has expired, previous attempts == max-1' do
    #     let(:two_days_ago) { Time.zone.now - 2.days }
    #     let(:user) { build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now) }
    #
    #     before do
    #       user.idv_attempts = max_attempts - 1
    #       user.idv_attempted_at = two_days_ago
    #       subject.idv_session.user_phone_confirmation = true
    #     end
    #
    #     it 'allows and does not affect attempt counter' do
    #       get :show
    #
    #       expect(response).to redirect_to idv_review_path
    #       expect(user.idv_attempts).to eq(max_attempts - 1)
    #       expect(user.idv_attempted_at).to eq two_days_ago
    #     end
    #   end
    #
    #   it 'passes the normalized phone to the background job' do
    #     user = build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now)
    #     stub_verify_steps_one_and_two(user)
    #
    #     subject.params = { phone: normalized_phone }
    #     expect(Idv::Job).to receive(:submit).
    #       with(subject.idv_session, [:address]).
    #       and_call_original
    #
    #     put :create, params: { idv_phone_form: { phone: good_phone } }
    #   end
    # end
  end
end
