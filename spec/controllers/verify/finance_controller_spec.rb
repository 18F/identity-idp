require 'rails_helper'

describe Verify::FinanceController do
  describe 'before_actions' do
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :confirm_idv_session_started,
        :confirm_idv_attempts_allowed
      )
    end
  end

  describe '#new' do
    it 'redirects to review when step is complete' do
      stub_subject
      subject.idv_session.financials_confirmation = true

      get :new

      expect(response).to redirect_to verify_phone_path
    end
  end

  describe '#create' do
    before do
      stub_subject
    end

    context 'when form is invalid' do
      context 'when finance_account is missing' do
        it 'renders #new' do
          put :create, idv_finance_form: { foo: 'bar' }

          expect(response).to render_template :new
          expect(subject.idv_session.params).to be_empty
        end
      end

      context 'when finance_type is invalid' do
        it 'renders #new with error' do
          put :create, idv_finance_form: { finance_type: 'foo', finance_account: '123' }

          expect(response).to render_template :new
          expect(subject.idv_session.params).to be_empty
        end
      end

      context 'when finance_type is ccn' do
        it 'renders verify/finance/new with error' do
          put :create, idv_finance_form: { finance_type: 'ccn', finance_account: 'abc' }

          expect(response).to render_template :new
          expect(subject.idv_session.params).to be_empty
        end
      end

      %w(mortgage auto_loan home_equity_line).each do |finance_type|
        context "when finance_type is #{finance_type}" do
          it 'renders verify/finance_other/new with error' do
            put :create, idv_finance_form: { finance_type: finance_type, finance_account: 'abc' }

            expect(response).to render_template :new
            expect(subject.idv_session.params).to be_empty
          end
        end
      end
    end

    context 'when form is valid' do
      it 'creates analytics event' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        put :create, idv_finance_form: { finance_type: :ccn, ccn: '12345678' }

        result = { success: true, errors: {} }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_FINANCE_CONFIRMATION, result
        )
      end

      context 'when CCN is confirmed' do
        it 'redirects to phone page' do
          put :create, idv_finance_form: { finance_type: :ccn, ccn: '12345678' }

          expect(response).to redirect_to verify_phone_url

          expected_params = { ccn: '12345678' }
          expect(subject.idv_session.params).to eq expected_params
        end
      end

      context 'when CCN is not confirmed' do
        it 'renders #new with error' do
          put :create, idv_finance_form: { finance_type: :ccn, ccn: '00000000' }

          expect(response).to render_template :new
        end
      end
    end
  end

  describe 'analytics' do
    before do
      stub_subject
      stub_analytics
      allow(@analytics).to receive(:track_event)
    end

    context 'when form is valid and CCN passes vendor validation' do
      it 'tracks the successful submission with no errors' do
        put :create, idv_finance_form: { finance_type: :ccn, ccn: '12345678' }

        result = {
          success: true,
          errors: {}
        }

        expect(@analytics).to have_received(:track_event).with(
          Analytics::IDV_FINANCE_CONFIRMATION, result
        )
      end
    end

    context 'when the form is valid but the CCN does not pass vendor validation' do
      it 'tracks the vendor error' do
        put :create, idv_finance_form: { finance_type: :ccn, ccn: '00000000' }

        result = {
          success: false,
          errors: { ccn: ['The ccn could not be verified.'] }
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::IDV_FINANCE_CONFIRMATION, result)
      end
    end

    context 'when the form is invalid' do
      it 'tracks the form errors and does not make a vendor API call' do
        allow(Idv::FinancialsValidator).to receive(:new)

        put :create, idv_finance_form: { finance_type: :ccn, ccn: '123' }

        result = {
          success: false,
          errors: { ccn: ['Credit card number should be only last 8 digits.'] }
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::IDV_FINANCE_CONFIRMATION, result)
        expect(subject.idv_session.financials_confirmation).to eq false
        expect(Idv::FinancialsValidator).to_not have_received(:new)
      end
    end
  end

  def stub_subject
    user = stub_sign_in
    idv_session = Idv::Session.new(subject.user_session, user)
    idv_session.resolution = Proofer::Resolution.new success: true, session_id: 'some-id'
    idv_session.applicant = Proofer::Applicant.new first_name: 'Some', last_name: 'One'
    idv_session.vendor = subject.idv_vendor.pick
    allow(subject).to receive(:confirm_idv_session_started).and_return(true)
    allow(subject).to receive(:confirm_idv_attempts_allowed).and_return(true)
    allow(subject).to receive(:idv_session).and_return(idv_session)
  end
end
