require 'rails_helper'

RSpec.describe Idv::UnavailableController, type: :controller do
  let(:idv_available) { false }

  before do
    allow(IdentityConfig.store).to receive(:idv_available).and_return(idv_available)
  end

  describe '#show' do
    let(:params) { nil }

    before do
      stub_analytics
      get :show, params:
    end

    it 'returns 200 OK' do
      # https://http.cat/200
      expect(response.status).to eql(200)
    end

    it 'logs an analytics event with redirect_from nil' do
      expect(@analytics).to have_logged_event(
        'Vendor Outage',
        redirect_from: nil,
        vendor_status: {
          acuant: :operational,
          lexisnexis_instant_verify: :operational,
          lexisnexis_trueid: :operational,
          sms: :operational,
          voice: :operational,
          idv_scheduled_maintenance: :operational,
        },
      )
    end

    it 'renders the view' do
      expect(response).to render_template('idv/unavailable/show')
    end

    context 'coming from the create account page' do
      let(:params) do
        { from: SignUp::RegistrationsController::CREATE_ACCOUNT }
      end
      it 'logs an analytics event with redirect_from CREATE_ACCOUNT' do
        expect(@analytics).to have_logged_event(
          'Vendor Outage',
          redirect_from: SignUp::RegistrationsController::CREATE_ACCOUNT,
          vendor_status: {
            acuant: :operational,
            lexisnexis_instant_verify: :operational,
            lexisnexis_trueid: :operational,
            sms: :operational,
            voice: :operational,
            idv_scheduled_maintenance: :operational,
          },
        )
      end
      it 'renders the view' do
        expect(response).to render_template('idv/unavailable/show')
      end
    end

    context 'IdV is enabled' do
      let(:idv_available) { true }

      it 'renders the view  when from: is nil' do
        expect(response).to render_template('idv/unavailable/show')
      end

      it 'returns a 200' do
        expect(response.status).to eql(200)
      end

      context 'coming from the create account page' do
        let(:params) { { from: SignUp::RegistrationsController::CREATE_ACCOUNT } }
        it 'redirects back to create account' do
          expect(response).to redirect_to(sign_up_email_path)
        end
      end
    end
  end
end
