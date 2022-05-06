require 'rails_helper'

describe VerifyController do
  describe '#show' do
    let(:idv_api_enabled_steps) { [] }
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

    subject(:response) { get :show }

    before do
      allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).
        and_return(idv_api_enabled_steps)
      stub_sign_in
      stub_idv_session
    end

    it 'renders 404' do
      expect(response).to be_not_found
    end

    context 'with personal key step enabled' do
      let(:idv_api_enabled_steps) { ['personal_key', 'personal_key_confirm'] }

      it 'renders view' do
        expect(response).to render_template(:show)
      end

      it 'sets app data' do
        response

        expect(assigns[:app_data]).to include(
          app_name: APP_NAME,
          base_path: idv_app_root_path,
          completion_url: idv_gpo_verify_url,
          enabled_step_names: idv_api_enabled_steps,
          initial_values: { 'personalKey' => kind_of(String) },
          store_key: kind_of(String),
        )
      end
    end

    context 'with password confirmation step enabled' do
      let(:idv_api_enabled_steps) { ['password_confirm', 'personal_key', 'personal_key_confirm'] }

      it 'renders view' do
        expect(response).to render_template(:show)
      end

      it 'sets app data' do
        response

        expect(assigns[:app_data]).to include(
          app_name: APP_NAME,
          base_path: idv_app_root_path,
          completion_url: idv_gpo_verify_url,
          enabled_step_names: idv_api_enabled_steps,
          initial_values: { 'userBundleToken' => kind_of(String) },
          store_key: kind_of(String),
        )
      end
    end

    def stub_idv_session
      stub_sign_in(user)
      idv_session = Idv::Session.new(
        user_session: controller.user_session,
        current_user: user,
        service_provider: nil,
      )
      idv_session.applicant = applicant
      idv_session.resolution_successful = true
      profile_maker = Idv::ProfileMaker.new(
        applicant: applicant,
        user: user,
        user_password: password,
      )
      profile = profile_maker.save_profile
      idv_session.pii = profile_maker.pii_attributes
      idv_session.profile_id = profile.id
      idv_session.personal_key = profile.personal_key
      allow(controller).to receive(:idv_session).and_return(idv_session)
    end
  end
end
