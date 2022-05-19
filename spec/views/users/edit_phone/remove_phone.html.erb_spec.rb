require 'rails_helper'

describe 'users/edit_phone/_remove_phone.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, :with_phone) }

  context 'when there are only 2 phone configurations' do
    let(:phone_configuration) { create(:phone_configuration, user: user, phone: '+1 703-555-1214') }
    before do
      allow(view).to receive(:current_user).and_return(user)
      assign(:phone_configuration, phone_configuration)
    end

    it 'renders a delete phone button' do
      render

      expect(rendered).to have_button('Remove phone')
    end
  end

  context 'when there is only 1 phone configuration' do
    before do
      allow(view).to receive(:current_user).and_return(user)
      assign(:phone_configuration, user.phone_configurations.first)
    end

    it 'renders a delete phone button' do
      render

      expect(rendered).to eq('')
    end
  end

  context 'when there is 1 phone configuration and 1 other configuration' do
    let(:user) { create(:user, :with_phone, :with_authentication_app) }

    before do
      allow(view).to receive(:current_user).and_return(user)
      assign(:phone_configuration, user.phone_configurations.first)
    end

    it 'renders a delete phone button' do
      render

      expect(rendered).to have_button('Remove phone')
    end
  end
end
