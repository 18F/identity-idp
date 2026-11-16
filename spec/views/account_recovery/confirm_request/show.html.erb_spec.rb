require 'rails_helper'

RSpec.describe 'account_recovery/confirm_request/show.html.erb' do
  before do
    allow(view).to receive(:email).and_return('signed-in@example.com')
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('account_recovery.confirm_request.header'))

    render
  end

  %i[en es fr zh].each do |locale|
    it "keeps the original simple confirmation in #{locale}" do
      I18n.with_locale(locale) do
        render

        expect(rendered).to have_css('h1', text: 'We received your account recovery request')
        expect(rendered).to have_css('strong', text: 'signed-in@example.com')
        expect(rendered).to have_css(
          'p',
          text: 'We sent an email to signed-in@example.com ' \
                'with instructions to recover your account.',
          count: 1,
        )
        expect(rendered).to have_css('p', count: 1)
      end
    end
  end

  it 'escapes the email address' do
    allow(view).to receive(:email).and_return('<script>alert(1)</script>@example.com')

    render

    expect(rendered).not_to have_css('script')
    expect(rendered).to include('&lt;script&gt;')
  end

  it 'does not offer cancellation, resend, or account navigation' do
    render

    expect(rendered).not_to have_css('form, a, button, hr')
    expect(rendered).not_to have_link(href: account_path)
  end
end
