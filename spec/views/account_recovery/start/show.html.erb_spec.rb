require 'rails_helper'

RSpec.describe 'account_recovery/start/show.html.erb' do
  before do
    assign(:waiting_period_interval, '24 hours')
  end

  it 'shows the standard question-mark illustration' do
    render

    expect(rendered).to have_css(
      'img.alert-icon[src*="info-question"][width="88"][height="88"]',
    )
    expect(rendered).to have_css("img[alt=\"#{t('image_description.info_question')}\"]")
  end

  %i[en es fr zh].each do |locale|
    it "renders the recovery page in #{locale}" do
      I18n.with_locale(locale) do
        render

        expect(rendered).to have_content(t('account_recovery.start.header'))
        expect(rendered).to have_content(
          t('account_recovery.start.intro', interval: '24 hours'),
        )
        expect(rendered).to have_button(t('account_recovery.start.continue'))
        expect(rendered).to have_link(
          t('account_recovery.start.keep_account_link_text'),
          href: MarketingSite.help_center_article_url(
            category: 'trouble-signing-in',
            article: 'issues-with-authentication-methods',
          ),
        )
        expect(rendered).not_to include('%{interval}', '%{link_html}', '&lt;a')
      end
    end
  end
end
