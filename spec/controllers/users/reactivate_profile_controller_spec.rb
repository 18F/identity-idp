require 'rails_helper'

RSpec.describe Users::ReactivateProfileController do
  include Features::LocalizationHelper

  describe '#create' do
    subject(:action) do
      post(
        :create,
        reactivate_profile_form: {
          password: 'password',
          recovery_code: 'recovery_code',
        }
      )
    end

    before do
      stub_sign_in

      form = instance_double('ReactivateProfileForm', submit: success)
      expect(controller).to receive(:build_reactivate_profile_form).and_return(form)
    end

    context 'with a valid form' do
      let(:success) { true }

      it 'redirects to the profile page' do
        action

        expect(response).to redirect_to(profile_path)
      end
    end

    context 'with an invalid form' do
      let(:success) { false }

      it 'renders the index page to show errors' do
        action

        expect(response).to render_template('users/reactivate_profile/index')
      end
    end
  end
end
