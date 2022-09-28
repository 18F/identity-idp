require 'rails_helper'

describe VerifyController do
  describe '#show' do
    let(:password) { 'sekrit phrase' }
    let(:user) { create(:user, :signed_up, password: password) }
    let(:applicant) do
      {
        first_name: 'Some',
        last_name: 'One',
        address1: '123 Any St',
        address2: 'Ste 456',
        city: 'Anywhere',
        state: 'KS',
        zipcode: '66666',
      }
    end
    let(:profile) { subject.idv_session.profile }
    let(:step) { '' }
    let(:sp) { nil }
    let(:sp_session) { { issuer: sp&.issuer } }

    subject(:response) { get :show, params: { step: step } }

    before do
      allow(controller).to receive(:current_sp).and_return(sp)
      stub_sign_in(user)
      stub_idv_session
      session[:sp] = sp_session if sp_session
    end

    it 'renders 404' do
      expect(response).to be_not_found
    end

    def stub_idv_session
      idv_session = Idv::Session.new(
        user_session: controller.user_session,
        current_user: user,
        service_provider: sp,
      )
      idv_session.applicant = applicant
      idv_session.resolution_successful = true
      allow(controller).to receive(:idv_session).and_return(idv_session)
    end
  end
end
