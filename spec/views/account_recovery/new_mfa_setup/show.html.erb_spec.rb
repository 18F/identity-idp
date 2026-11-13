require 'rails_helper'

RSpec.describe 'account_recovery/new_mfa_setup/show.html.erb' do
  let(:user) { create(:user, :fully_registered) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:user_session).and_return({})
    allow(view).to receive(:nds_layout?).and_return(false)
    allow_any_instance_of(OutageStatus).to receive(:vendor_outage?).and_return(false)

    @two_factor_options_form = TwoFactorOptionsForm.new(
      user: user,
      phishing_resistant_required: false,
      piv_cac_required: false,
    )
    @presenter = TwoFactorOptionsPresenter.new(
      user: user,
      user_agent: nil,
      phishing_resistant_required: false,
      piv_cac_required: false,
    )
  end

  %i[en es fr zh].each do |locale|
    it "explains the recovery session in #{locale}" do
      I18n.with_locale(locale) do
        render

        expect(rendered).to have_content(t('two_factor_authentication.two_factor_choice'))
        expect(rendered).to have_content(t('account_recovery.new_mfa_setup.banner'))
      end
    end
  end

  it 'explains that new methods replace the old ones and finish recovery' do
    render

    expect(rendered).to have_content(t('account_recovery.new_mfa_setup.banner'))
    expect(rendered).to have_content(t('mfa.info', app_name: APP_NAME))
  end

  it 'offers every enrollment method as a checkbox' do
    render

    expect(rendered).to have_css(
      'input[type="checkbox"][name="two_factor_options_form[selection][]"]',
      count: @presenter.options.count,
      visible: :all,
    )
    expect(rendered).not_to have_css('input[type="radio"]')
    expect(rendered).to have_field('recovery_mfa_auth_app', type: 'checkbox')
    expect(rendered).to have_button(t('forms.buttons.continue'))
    expect(rendered).to have_css(
      "form[action=\"#{account_recovery_new_mfa_setup_path}\"][method=\"post\"]",
    )
    expect(rendered).not_to have_link(href: /skip|cancel/)
    expect(rendered).not_to have_link(href: %r{/authentication_methods_setup})
  end
end
