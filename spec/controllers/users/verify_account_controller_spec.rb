require 'rails_helper'

RSpec.describe Users::VerifyAccountController do
  include Features::LocalizationHelper

  describe '#create' do
    subject(:action) do
      post(
        :create,
        verify_account_form: {
          otp: 'abc123',
        }
      )
    end

    before do
      stub_sign_in

      form = instance_double('VerifyAccountForm', submit: success)
      expect(controller).to receive(:build_verify_account_form).and_return(form)
    end

    context 'with a valid form' do
      let(:success) { true }

      it 'redirects to the profile page' do
        action

        expect(response).to redirect_to(account_path)
      end
    end

    context 'with an invalid form' do
      let(:success) { false }

      it 'renders the index page to show errors' do
        action

        expect(response).to render_template('users/verify_account/index')
      end
    end
  end
end
