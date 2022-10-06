require 'rails_helper'

describe 'two_factor_authentication/options/index.html.erb' do
  let(:user) { User.new }
  before do
    allow(view).to receive(:user_session).and_return({})
    allow(view).to receive(:current_user).and_return(User.new)

    @presenter = TwoFactorLoginOptionsPresenter.new(
      user: user,
      view: view,
      user_session_context: UserSessionContext::AUTHENTICATION_CONTEXT,
      service_provider: nil,
      phishing_resistant_required: false,
      piv_cac_required: false,
    )
    @two_factor_options_form = TwoFactorLoginOptionsForm.new(user)
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with( \
      t('two_factor_authentication.login_options_title'),
    )

    render
  end

  it 'has a localized heading' do
    render

    expect(rendered).to have_content \
      t('two_factor_authentication.login_options_title')
  end

  it 'has a cancel link' do
    render

    expect(rendered).to have_link(t('links.cancel_account_creation'), href: sign_up_cancel_path)
  end

  context 'phone vendor outage' do
    before do
      create(:phone_configuration, user: user, phone: '(202) 555-1111')
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).and_return(false)
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:sms).and_return(true)

      render
    end

    it 'renders alert banner' do
      expect(rendered).to have_selector('.usa-alert.usa-alert--error')
    end

    it 'disables problematic vendor option' do
      expect(rendered).to have_checked_field(
        'two_factor_options_form[selection]',
        with: :voice,
        disabled: false,
      )
      expect(rendered).to have_field(
        'two_factor_options_form[selection]',
        with: :sms,
        disabled: true,
      )
    end
  end
end
