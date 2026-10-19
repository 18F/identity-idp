require 'rails_helper'

RSpec.describe 'account_recovery/verify/show.html.erb' do
  before do
    assign(:email, 'signed-in@example.com')
    assign(:token, 'recovery-token')
  end

  %i[en es fr zh].each do |locale|
    it "prompts for the password in #{locale}" do
      I18n.with_locale(locale) do
        render

        expect(rendered).to have_content(t('account_recovery.verify.header'))
        expect(rendered).to have_css('strong', text: 'signed-in@example.com', count: 1)
        expect(rendered).to have_button(t('account_recovery.verify.continue'))
        expect(rendered).to have_css(
          "form[action=\"#{account_recovery_verify_path}\"][method=\"post\"]",
        )
        expect(rendered).to_not include('%{email}', '&lt;a')
        expect(rendered).to have_css(
          'input[type="hidden"][name="token"][value="recovery-token"]',
          visible: false,
        )
      end
    end
  end

  it 'does not offer cancellation after token verification' do
    render

    expect(rendered).not_to have_css('form[action*="cancel"], a[href*="cancel"]')
  end

  it 'escapes email addresses' do
    assign(:email, '<script>alert(1)</script>@example.com')

    render

    expect(rendered).to_not have_css('script')
    expect(rendered).to include('&lt;script&gt;')
  end

  it 'masks the password field' do
    render

    expect(rendered).to have_css('input[type="password"]')
  end
end
