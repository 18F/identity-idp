require 'rails_helper'

RSpec.describe 'account_recovery/pending/show.html.erb' do
  before do
    assign(:waiting_period_interval, '1 day')
    assign(:email, 'signed-in@example.com')
  end

  %i[en es fr zh].each do |locale|
    it "shows the sign-in email and instructions in #{locale}" do
      I18n.with_locale(locale) do
        render

        expect(rendered).to have_css('strong', text: 'signed-in@example.com', count: 1)
        expect(rendered).to have_content(t('account_recovery.pending.instructions'))
        expect(rendered).to have_content(t('account_recovery.pending.close_window'))
        expect(rendered).to have_content(t('account_recovery.pending.wait', interval: '1 day'))
      end
    end
  end

  it 'escapes email addresses in the confirmation' do
    assign(:email, '<script>alert(1)</script>@example.com')

    render

    expect(rendered).not_to have_css('script')
    expect(rendered).to include('&lt;script&gt;')
  end

  it 'explains that leaving the page does not cancel the request' do
    render

    expect(rendered).to include(t('account_recovery.pending.leaving_does_not_cancel'))
    expect(rendered).to have_link(
      t('account_recovery.pending.return_home'),
      href: root_path,
    )
  end
end
