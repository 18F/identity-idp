require 'rails_helper'

describe VerifyController do
  describe '#show' do
    let(:idv_api_enabled_steps) { [] }
    let(:in_person_proofing_enabled) { false }
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
    let(:sp) { build(:service_provider) }
    let(:sp_session) { { issuer: sp.issuer } }

    subject(:response) { get :show, params: { step: step } }

    before do
      allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).
        and_return(idv_api_enabled_steps)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
        and_return(in_person_proofing_enabled)
      stub_sign_in(user)
      stub_idv_session
      session[:sp] = sp_session if sp_session
    end

    it 'renders 404' do
      expect(response).to be_not_found
    end

    context 'with idv api enabled' do
      let(:idv_api_enabled_steps) { ['password_confirm', 'personal_key', 'personal_key_confirm'] }
      let(:step) { 'password_confirm' }

      context 'invalid step' do
        let(:step) { 'bad' }

        it 'renders 404' do
          expect(response).to be_not_found
        end
      end

      it 'renders view' do
        expect(response).to render_template(:show)
      end

      it 'sets app data' do
        response

        expect(assigns[:app_data]).to include(
          base_path: idv_app_path,
          cancel_url: idv_cancel_path,
          in_person_url: nil,
          enabled_step_names: idv_api_enabled_steps,
          initial_values: { 'userBundleToken' => kind_of(String) },
          store_key: kind_of(String),
        )
      end

      context 'empty step' do
        let(:step) { nil }

        it 'renders view' do
          expect(response).to render_template(:show)
        end
      end

      context 'with in-person proofing enabled' do
        let(:in_person_proofing_enabled) { true }

        it 'includes in-person URL as app data' do
          response

          expect(assigns[:app_data][:in_person_url]).to eq(idv_in_person_url)
        end
      end
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
