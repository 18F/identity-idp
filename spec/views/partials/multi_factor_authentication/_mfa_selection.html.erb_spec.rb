require 'rails_helper'

RSpec.describe 'partials/multi_factor_authentication/_mfa_selection.html.erb' do
  include Devise::Test::ControllerHelpers

  let(:user) { create(:user) }
  let(:presenter) { TwoFactorOptionsPresenter.new(user_agent: nil, user: user) }
  let(:option) { presenter.options.find { |o| o.type == :phone } }
  subject(:rendered) do
    render partial: 'partials/multi_factor_authentication/mfa_selection', locals: { option: }
  end

  it 'renders a submit card for the option' do
    expect(rendered).to have_button(
      type: 'submit',
      id: 'two_factor_options_form_selection_phone',
    )
    expect(rendered).to have_content(option.label)
    expect(rendered).to have_content(option.info)
  end

  context 'when option is disabled' do
    before do
      allow(option).to receive(:disabled?).and_return(true)
    end

    it 'renders a disabled card without chevron or description' do
      expect(rendered).to have_css('#two_factor_options_form_selection_phone[disabled]')
      expect(rendered).not_to have_css('.ads-card__trailing')
      expect(rendered).not_to have_css('.ads-card__description')
    end
  end

  context 'when option is recommended' do
    let(:option) { presenter.options.find { |o| o.type == :webauthn_platform } }

    it 'renders recommended badge' do
      expect(rendered).to have_css(
        '.ads-card__badge',
        text: t('two_factor_authentication.recommended'),
      )
    end
  end

  context 'when configuration already exists' do
    let(:user) { create(:user, :with_piv_or_cac) }
    let(:option) { presenter.options.find { |o| o.type == :piv_cac } }

    it 'communicates the configuration is enabled' do
      expect(rendered).to have_content(
        t('two_factor_authentication.two_factor_choice_options.no_count_configuration_enabled'),
      )
    end
  end
end
