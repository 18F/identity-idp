require 'rails_helper'

describe Verify::PhoneController do
  include Features::LocalizationHelper

  let(:max_attempts) { Idv::Attempter.idv_max_attempts }
  let(:good_phone) { '+1 (555) 555-0000' }
  let(:normalized_phone) { '5555550000' }
  let(:bad_phone) { '+1 (555) 555-5555' }

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

        expect(response).to redirect_to verify_review_path
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

      expect(response).to redirect_to verify_fail_path
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
        put :create, params: { idv_phone_form: { phone: '703', international_code: 'US' } }

        expect(flash[:warning]).to be_nil
        expect(subject.idv_session.params).to be_empty
      end

      it 'tracks form error and does not make a vendor API call' do
        expect(Idv::SubmitIdvJob).to_not receive(:submit_phone_job)

        put :create, params: { idv_phone_form: { phone: '703' } }

        result = {
          success: false,
          errors: {
            phone: [invalid_phone_message],
          },
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

        put :create, params: { idv_phone_form: { phone: good_phone, international_code: 'US' } }

        result = { success: true, errors: {} }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_PHONE_CONFIRMATION_FORM, result
        )
      end

      context 'when same as user phone' do
        it 'redirects to result page and sets phone_confirmed_at' do
          user = build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now)
          stub_verify_steps_one_and_two(user)

          put :create, params: { idv_phone_form: { phone: good_phone, international_code: 'US' } }

          expect(response).to redirect_to verify_phone_result_path

          expected_params = {
            phone: normalized_phone,
            phone_confirmed_at: user.phone_confirmed_at,
          }
          expect(subject.idv_session.params).to eq expected_params
        end
      end

      context 'when different from user phone' do
        it 'redirects to otp page and does not set phone_confirmed_at' do
          user = build(:user, phone: '+1 (415) 555-0130', phone_confirmed_at: Time.zone.now)
          stub_verify_steps_one_and_two(user)

          put :create, params: { idv_phone_form: { phone: good_phone, international_code: 'US' } }

          expect(response).to redirect_to verify_phone_result_path

          expected_params = {
            phone: normalized_phone,
            phone_confirmed_at: nil,
          }
          expect(subject.idv_session.params).to eq expected_params
        end
      end
    end
  end

  describe '#show' do
    let(:user) { build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now) }
    let(:params) { { phone: good_phone } }

    before do
      stub_verify_steps_one_and_two(user)
      controller.idv_session.params = params
    end

    context 'when the background job is not complete yet' do
      render_views

      it 'renders a spinner and has the page refresh' do
        get :show

        expect(response).to render_template('shared/refresh')

        dom = Nokogiri::HTML(response.body)
        expect(dom.css('meta[http-equiv="refresh"]')).to be_present
      end
    end

    context 'when the background job has timed out' do
      let(:expired_started_at) do
        Time.zone.now.to_i - Figaro.env.async_job_refresh_max_wait_seconds.to_i
      end

      before do
        controller.idv_session.async_result_started_at = expired_started_at
      end

      it 'displays an error' do
        get :show

        expect(response).to render_template :new
        expect(flash[:warning]).to include(t('idv.modal.phone.timeout'))
      end

      it 'tracks the failure as a timeout' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        get :show

        result = {
          success: false,
          errors: { timed_out: ['Timed out waiting for vendor response'] },
        }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_PHONE_CONFIRMATION_VENDOR, result
        )
      end
    end

    context 'when the background job has completed' do
      let(:result_id) { SecureRandom.uuid }

      before do
        controller.idv_session.async_result_id = result_id
        VendorValidatorResultStorage.new.store(result_id: result_id, result: result)
      end

      let(:result) { Idv::VendorResult.new(success: true) }

      context 'when the phone is invalid' do
        let(:result) do
          Idv::VendorResult.new(
            success: false,
            errors: { phone: ['The phone number could not be verified.'] }
          )
        end

        let(:params) { { phone: bad_phone } }
        let(:user) { build(:user, phone: bad_phone, phone_confirmed_at: Time.zone.now) }

        it 'tracks event with invalid phone' do
          stub_analytics
          allow(@analytics).to receive(:track_event)

          get :show

          result = {
            success: false,
            errors: {
              phone: ['The phone number could not be verified.'],
            },
          }

          expect(flash[:warning]).to match t('idv.modal.phone.heading')
          expect(flash[:warning]).to match t('idv.modal.attempts', count: max_attempts - 1)
          expect(@analytics).to have_received(:track_event).with(
            Analytics::IDV_PHONE_CONFIRMATION_VENDOR, result
          )
        end
      end

      context 'attempt window has expired, previous attempts == max-1' do
        let(:two_days_ago) { Time.zone.now - 2.days }
        let(:user) { build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now) }

        before do
          user.idv_attempts = max_attempts - 1
          user.idv_attempted_at = two_days_ago
          subject.idv_session.user_phone_confirmation = true
        end

        it 'allows and does not affect attempt counter' do
          get :show

          expect(response).to redirect_to verify_review_path
          expect(user.idv_attempts).to eq(max_attempts - 1)
          expect(user.idv_attempted_at).to eq two_days_ago
        end
      end

      it 'passes the normalized phone to the background job' do
        user = build(:user, phone: good_phone, phone_confirmed_at: Time.zone.now)
        stub_verify_steps_one_and_two(user)

        expect(Idv::SubmitIdvJob).to receive(:new).with(
          idv_session: subject.idv_session,
          vendor_params: normalized_phone
        ).and_call_original

        put :create, params: { idv_phone_form: { phone: good_phone } }
      end
    end
  end
end
