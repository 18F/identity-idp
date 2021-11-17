require 'rails_helper'

describe 'users/phones/add.html.erb' do
  include Devise::Test::ControllerHelpers

  subject(:rendered) { render }

  before do
    user = build_stubbed(:user)
    @new_phone_form = NewPhoneForm.new(user)
  end

  context 'phone vendor outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).and_return(false)
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
    end

    it 'renders alert banner' do
      expect(rendered).to have_selector('.usa-alert.usa-alert--error')
    end
  end
end
