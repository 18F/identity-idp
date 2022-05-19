require 'rails_helper'

describe 'users/edit_phone/_remove_phone.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user, :with_phone) }
  let(:phone_configuration) { create(:phone_configuration, user: user, phone: '+1 703-555-1214') }

  context 'with multi mfa disabled' do
    before do
      allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return false
      assign(:phone_configuration, phone_configuration)
    end

    it 'does not render a delete phone button' do
      render

      expect(rendered).to eq('')
    end
  end

  context 'with multi mfa enabled' do
    before do
      allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return true
      assign(:phone_configuration, phone_configuration)
    end

    it 'renders a delete phone button' do
      render

      expect(rendered).to have_button('Remove phone')
    end
  end
end
