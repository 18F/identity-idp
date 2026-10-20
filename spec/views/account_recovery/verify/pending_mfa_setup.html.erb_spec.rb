require 'rails_helper'

RSpec.describe 'account_recovery/verify/pending_mfa_setup.html.erb' do
  %i[en es fr zh].each do |locale|
    it "explains that MFA setup is not available yet in #{locale}" do
      I18n.with_locale(locale) do
        render

        expect(rendered).to have_content(t('account_recovery.pending_mfa_setup.header'))
        expect(rendered).to have_content(t('account_recovery.pending_mfa_setup.intro'))
      end
    end
  end

  it 'does not offer cancellation after password verification' do
    render

    expect(rendered).not_to have_css('form[action*="cancel"], a[href*="cancel"]')
  end

  it 'does not link to MFA setup' do
    render

    expect(rendered).to_not have_link(href: %r{/account_recovery/new_mfa_setup})
    expect(rendered).to_not have_link(href: %r{/authentication_methods_setup})
  end
end
