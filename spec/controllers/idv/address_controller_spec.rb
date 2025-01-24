require 'rails_helper'

RSpec.describe Idv::AddressController do
  let(:user) { create(:user) }

  let(:pii_from_doc) { Pii::StateId.new(**Idp::Constants::MOCK_IDV_APPLICANT) }

  before do
    stub_sign_in(user)
    stub_analytics
    subject.idv_session.welcome_visited = true
    subject.idv_session.idv_consent_given_at = Time.zone.now
    subject.idv_session.flow_path = 'standard'
    subject.idv_session.pii_from_doc = pii_from_doc
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::AddressController.step_info).to be_valid
    end
  end

  describe '#new' do
    it 'logs an analytics event' do
      get :new
      expect(@analytics).to have_logged_event('IdV: address visited')
    end

    context 'verify_info already submitted' do
      before do
        subject.idv_session.resolution_successful = true
      end

      it 'renders the :new template' do
        get :new

        expect(response).to render_template(:new)
      end
    end
  end

  describe '#update' do
    let(:params) do
      {
        idv_form: {
          address1: '1234 Main St',
          address2: 'Apt B',
          city: 'Beverly Hills',
          state: 'CA',
          zipcode: '90210',
        },
      }
    end

    it 'redirects to verify info on success' do
      put :update, params: params
      expect(response).to redirect_to(idv_verify_info_url)
    end

    it 'sets address_edited in idv_session' do
      expect do
        put :update, params: params
      end.to change { subject.idv_session.address_edited }.from(nil).to eql(true)
    end

    it 'adds updated_user_data to idv_session' do
      expect do
        put :update, params: params
      end.to change { subject.idv_session.updated_user_address }

      expect(subject.idv_session.updated_user_address).to eql(
        Pii::Address.new(
          address1: '1234 Main St',
          address2: 'Apt B',
          city: 'Beverly Hills',
          state: 'CA',
          zipcode: '90210',
        ),
      )
    end

    it 'invalidates future steps' do
      expect(subject).to receive(:clear_future_steps!)

      put :update, params: params
    end

    it 'logs an analytics event' do
      put :update, params: params
      expect(@analytics).to have_logged_event(
        'IdV: address submitted',
        success: true,
        address_edited: true,
      )
    end

    context 'with invalid params' do
      render_views

      it 'renders errors if they occur' do
        params[:idv_form][:zipcode] = 'this is invalid'

        put :update, params: params

        expect(response).to render_template(:new)
        expect(response.body).to include(t('idv.errors.pattern_mismatch.zipcode'))
      end
    end

    it 'has the correct `address_edited` value when submitted twice with the same data' do
      put :update, params: params
      expect(subject.idv_session.address_edited).to eq(true)
      put :update, params: params
      expect(subject.idv_session.address_edited).to eq(true)
    end
  end
end
