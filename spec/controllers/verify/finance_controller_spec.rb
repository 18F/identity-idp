require 'rails_helper'

describe Verify::FinanceController do
  let(:max_attempts) { Idv::Attempter.idv_max_attempts }

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
    it 'redirects to review when step is complete' do
      stub_subject
      subject.idv_session.financials_confirmation = true

      get :new

      expect(response).to redirect_to verify_address_path
    end

    it 'redirects to fail when step attempts are exceeded' do
      stub_subject
      subject.idv_session.step_attempts[:financials] = max_attempts

      get :new

      expect(response).to redirect_to verify_fail_path
    end
  end

  describe '#create' do
    before do
      stub_subject
    end

    context 'when form is invalid' do
      context 'when finance_account is missing' do
        it 'renders #new' do
          put :create, params: { idv_finance_form: { foo: 'bar' } }

          expect(response).to render_template :new
          expect(flash[:warning]).to be_nil
          expect(subject.idv_session.params).to be_empty
        end
      end

      context 'when finance_type is invalid' do
        it 'renders #new with error' do
          put :create, params: { idv_finance_form: { finance_type: 'foo', finance_account: '123' } }

          expect(response).to render_template :new
          expect(flash[:warning]).to be_nil
          expect(subject.idv_session.params).to be_empty
        end
      end

      context 'when finance_type is ccn' do
        it 'renders verify/finance/new with error' do
          put :create, params: { idv_finance_form: { finance_type: 'ccn', finance_account: 'abc' } }

          expect(response).to render_template :new
          expect(flash[:warning]).to be_nil
          expect(subject.idv_session.params).to be_empty
        end
      end

      %w[mortgage auto_loan home_equity_line].each do |finance_type|
        context "when finance_type is #{finance_type}" do
          it 'renders verify/finance_other/new with error' do
            put :create, params: {
              idv_finance_form: { finance_type: finance_type, finance_account: 'abc' },
            }

            expect(response).to render_template :new
            expect(flash[:warning]).to be_nil
            expect(subject.idv_session.params).to be_empty
          end
        end
      end

      it 'tracks the form errors and does not make a vendor API call' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        expect(Idv::SubmitIdvJob).to_not receive(:submit_finance_job)

        put :create, params: { idv_finance_form: { finance_type: :ccn, ccn: '123' } }

        result = {
          success: false,
          errors: { ccn: ['Credit card number should be only last 8 digits.'] },
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::IDV_FINANCE_CONFIRMATION_FORM, result)
        expect(subject.idv_session.financials_confirmation).to be_falsy
      end
    end

    context 'when form is valid' do
      it 'redirects to the show page' do
        put :create, params: { idv_finance_form: { finance_type: :ccn, ccn: '12345678' } }

        expect(response).to redirect_to(verify_finance_result_path)
      end

      it 'tracks the successful submission with no errors' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :create, params: { idv_finance_form: { finance_type: :ccn, ccn: '12345678' } }

        result = {
          success: true,
          errors: {},
        }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_FINANCE_CONFIRMATION_FORM, result
        )
      end
    end
  end

  describe '#show' do
    before do
      stub_subject
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
        controller.idv_session.params = { ccn: '12345678' }
      end

      it 'displays an error' do
        get :show

        expect(response).to render_template :new
        expect(flash[:warning]).to include(t('idv.modal.financials.timeout'))
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
          Analytics::IDV_FINANCE_CONFIRMATION_VENDOR, result
        )
      end
    end

    context 'when the background job has completed' do
      let(:result_id) { SecureRandom.uuid }

      before do
        controller.idv_session.async_result_id = result_id
        VendorValidatorResultStorage.new.store(result_id: result_id, result: result)
      end

      context 'when CCN is confirmed' do
        let(:result) { Idv::VendorResult.new(success: true) }

        it 'redirects to phone page' do
          controller.idv_session.params = { ccn: '12345678' }

          get :show

          expect(flash[:success]).to eq(t('idv.messages.personal_details_verified'))
          expect(response).to redirect_to verify_address_url

          expected_params = { ccn: '12345678' }
          expect(subject.idv_session.params).to eq expected_params
        end

        it 'tracks the successful submission with no errors' do
          stub_analytics
          allow(@analytics).to receive(:track_event)

          get :show

          result = {
            success: true,
            errors: {},
          }

          expect(@analytics).to have_received(:track_event).with(
            Analytics::IDV_FINANCE_CONFIRMATION_VENDOR, result
          )
        end
      end

      context 'when CCN is not confirmed' do
        let(:result) do
          Idv::VendorResult.new(
            success: false,
            errors: { ccn: ['The ccn could not be verified.'] }
          )
        end

        before do
          controller.idv_session.params = { finance_type: 'ccn', ccn: '00000000' }
        end

        it 'renders #new with error' do
          get :show

          expect(flash[:warning]).to match t('idv.modal.financials.heading')
          expect(flash[:warning]).to match t('idv.modal.attempts', count: max_attempts - 1)
          expect(response).to render_template :new
        end

        it 'tracks the vendor error' do
          stub_analytics
          allow(@analytics).to receive(:track_event)

          get :show

          result = {
            success: false,
            errors: { ccn: ['The ccn could not be verified.'] },
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::IDV_FINANCE_CONFIRMATION_VENDOR, result)
        end
      end

      context 'attempt window has expired, previous attempts == max-1' do
        let(:result) { Idv::VendorResult.new(success: true) }
        let(:two_days_ago) { Time.zone.now - 2.days }

        before do
          subject.current_user.idv_attempts = max_attempts - 1
          subject.current_user.idv_attempted_at = two_days_ago
        end

        it 'allows and does not affect attempt counter' do
          get :show

          expect(response).to redirect_to verify_address_path
          expect(subject.current_user.idv_attempts).to eq(max_attempts - 1)
          expect(subject.current_user.idv_attempted_at).to eq two_days_ago
        end
      end
    end
  end

  def stub_subject
    user = stub_sign_in
    idv_session = Idv::Session.new(
      user_session: subject.user_session,
      current_user: user,
      issuer: nil
    )
    idv_session.applicant = Proofer::Applicant.new first_name: 'Some', last_name: 'One'
    allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    allow(subject).to receive(:idv_session).and_return(idv_session)
  end
end
