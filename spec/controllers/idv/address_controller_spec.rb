require 'rails_helper'

RSpec.describe Idv::AddressController do
  include IdvHelper

  let(:user) { create(:user) }

  let(:idv_session) { subject.idv_session }

  let(:pii_from_doc) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.stringify_keys }

  let(:flow_session) do
    { pii_from_doc: pii_from_doc }
  end

  before do
    stub_sign_in(user)
    stub_analytics
    stub_idv_steps_before_verify_step(user)
    subject.idv_session.flow_path = 'standard'
    subject.idv_session.pii_from_doc = pii_from_doc
    subject.user_session['idv/doc_auth'] = flow_session
  end

  describe '#new' do
    before do
      get :new
    end

    it 'logs an analytics event' do
      expect(@analytics).to have_logged_event('IdV: address visited')
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
      end.to change { idv_session.address_edited }.from(nil).to eql(true)
    end

    it 'updates pii_from_doc in flow_session (even if nil)' do
      flow_session[:pii_from_doc] = nil
      expect do
        put :update, params: params
      end.to change { flow_session[:pii_from_doc] }.to eql(
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

    it 'updates pii_from_doc in idv_session (even if nil)' do
      subject.idv_session.pii_from_doc = nil
      expect do
        put :update, params: params
      end.to change { idv_session.pii_from_doc }.to eql(
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
