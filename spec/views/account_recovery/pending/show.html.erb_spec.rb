require 'rails_helper'

RSpec.describe 'account_recovery/pending/show.html.erb' do
  before do
    assign(:waiting_period_interval, '1 day')
    assign(:email, 'signed-in@example.com')
  end

  %i[en es fr zh].each do |locale|
    it "shows the sign-in email and support link in #{locale}" do
      I18n.with_locale(locale) do
        render

        expect(rendered).to have_css('strong', text: 'signed-in@example.com', count: 1)
        expect(rendered).to have_content(t('components.troubleshooting_options.default_heading'))
        expect(rendered).to have_link(
          t('account_recovery.pending.help'),
          href: MarketingSite.help_center_article_url(
            category: 'trouble-signing-in',
            article: 'issues-with-authentication-methods',
          ),
          target: '_blank',
        )
        expect(rendered).to have_css('lg-form-link a', text: t('account_recovery.pending.resend'))
        expect(rendered).to have_css(
          "form[action=\"#{account_recovery_resend_path}\"][method=\"post\"]",
        )
      end
    end
  end

  it 'escapes email addresses in the confirmation' do
    assign(:email, '<script>alert(1)</script>@example.com')

    render

    expect(rendered).not_to have_css('script')
    expect(rendered).to include('&lt;script&gt;')
  end

  it 'does not offer home or cancellation navigation' do
    render

    expect(rendered).not_to have_link(href: root_path)
    expect(rendered).not_to have_css('form[action*="cancel"], a[href*="cancel"]')
  end
end
