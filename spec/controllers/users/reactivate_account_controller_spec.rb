require 'rails_helper'

RSpec.describe Users::ReactivateAccountController do
  include Features::LocalizationHelper

  describe '#create' do
    subject(:action) do
      post(
        :create,
        reactivate_account_form: {
          password: 'password',
          personal_key: 'personal_key',
        }
      )
    end

    before do
      stub_sign_in

      form = instance_double('ReactivateAccountForm', submit: success)
      expect(controller).to receive(:build_reactivate_account_form).and_return(form)
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

        expect(response).to render_template('users/reactivate_account/index')
      end
    end
  end
end
