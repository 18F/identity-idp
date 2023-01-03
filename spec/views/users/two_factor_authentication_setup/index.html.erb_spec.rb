require 'rails_helper'

describe 'users/two_factor_authentication_setup/index.html.erb' do
  include Devise::Test::ControllerHelpers

  subject(:rendered) { render }

  before do
    user = build_stubbed(:user)
    @presenter = TwoFactorOptionsPresenter.new(user_agent: '', user: user)
    @two_factor_options_form = TwoFactorLoginOptionsForm.new(user)
  end

  context 'all phone vendor outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:all_vendor_outage?).
        with(VendorStatus::PHONE_VENDORS).and_return(true)
    end

    it 'renders alert banner' do
      expect(rendered).to have_selector('.usa-alert.usa-alert--error')
    end

    it 'disables phone option' do
      expect(rendered).to have_field(
        'two_factor_options_form[selection][]',
        with: :phone,
        disabled: true,
      )
    end
  end

  context 'single phone vendor outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).and_return(false)
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
    end

    it 'does not render alert banner' do
      expect(rendered).to_not have_selector('.usa-alert.usa-alert--error')
    end

    it 'does not disable phone option' do
      expect(rendered).to have_field(
        'two_factor_options_form[selection][]',
        with: :phone,
        disabled: false,
      )
    end
  end
end
