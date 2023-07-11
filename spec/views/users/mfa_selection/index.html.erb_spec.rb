require 'rails_helper'

RSpec.describe 'users/mfa_selection/index.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }
  let(:phishing_resistant_required) { true }
  let(:piv_cac_required) { true }
  let(:user_agent) { '' }
  let(:show_skip_additional_mfa_link) { true }

  before do
    allow(view).to receive(:current_user).and_return(user)

    @two_factor_options_form ||= TwoFactorOptionsForm.new(
      user: user,
      phishing_resistant_required: phishing_resistant_required,
      piv_cac_required: piv_cac_required,
    )

    @presenter = TwoFactorOptionsPresenter.new(
      user_agent: user_agent,
      user: user,
      phishing_resistant_required: phishing_resistant_required,
      piv_cac_required: piv_cac_required,
      show_skip_additional_mfa_link: show_skip_additional_mfa_link,
    )
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('mfa.additional_mfa_required.heading'))

    render
  end

  it 'has intro text' do
    render

    expect(rendered).to have_content(@presenter.intro)
  end

  it 'has link to skip add mfa' do
    render

    expect(rendered).to have_link(t('mfa.skip'))
  end

  context 'when show_skip_additional_mfa_link is false' do
    let(:show_skip_additional_mfa_link) { false }

    before do
      @presenter = TwoFactorOptionsPresenter.new(
        user_agent: user_agent,
        user: user,
        phishing_resistant_required: phishing_resistant_required,
        piv_cac_required: piv_cac_required,
        show_skip_additional_mfa_link: show_skip_additional_mfa_link,
      )
    end

    it 'does not show link to skip add mfa' do
      render

      expect(rendered).not_to have_link(t('mfa.skip'))
    end
  end
end
