require 'rails_helper'

RSpec.describe Idv::AddressController do
  let(:user) { create(:user) }

  let(:pii_from_doc) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.stringify_keys }

  before do
    stub_sign_in(user)
    stub_analytics
    stub_idv_steps_before_verify_step(user)
    subject.idv_session.welcome_visited = true
    subject.idv_session.idv_consent_given = true
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

      it 'redirects to enter_password' do
        get :new

        expect(response).to redirect_to(idv_enter_password_url)
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

    it 'updates pii_from_doc in idv_session' do
      expect do
        put :update, params: params
      end.to change { subject.idv_session.pii_from_doc }.to eql(
        pii_from_doc.merge(
          {
            'address1' => '1234 Main St',
            'address2' => 'Apt B',
            'city' => 'Beverly Hills',
            'state' => 'CA',
            'zipcode' => '90210',
          },
        ),
      )
    end

    it 'logs an analytics event' do
      put :update, params: params
      expect(@analytics).to have_logged_event(
        'IdV: address submitted',
        { success: true,
          errors: {},
          address_edited: true,
          error_details: nil },
      )
    end
  end
end
