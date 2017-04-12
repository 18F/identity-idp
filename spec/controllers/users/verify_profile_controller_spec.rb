require 'rails_helper'

RSpec.describe Users::VerifyProfileController do
  include Features::LocalizationHelper

  describe '#create' do
    subject(:action) do
      post(
        :create,
        verify_profile_form: {
          otp: 'abc123',
        }
      )
    end

    before do
      stub_sign_in

      form = instance_double('VerifyProfileForm', submit: success)
      expect(controller).to receive(:build_verify_profile_form).and_return(form)
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

        expect(response).to render_template('users/verify_profile/index')
      end
    end
  end
end
