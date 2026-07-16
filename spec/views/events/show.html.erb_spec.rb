require 'rails_helper'

RSpec.describe 'events/show.html.erb' do
  let(:user) { create(:user, :fully_registered) }
  let(:device) do
    create(
      :device,
      user: user,
      user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) ' \
                  'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36',
    )
  end
  let(:events) do
    [create(:event, event_type: :sign_in_after_2fa, user: user, device: device).decorate]
  end

  before do
    assign(:device, device.decorate)
    assign(:events, events)
    render
  end

  it 'renders the device name as the page heading' do
    expect(rendered).to have_css('h1', text: device.decorate.nice_name)
  end

  it 'renders a back button labelled to return to history' do
    expect(rendered).to have_css(
      "a[aria-label='#{t('account.dashboard.history.back_to_history')}']",
    )
    expect(rendered).to have_link(
      t('account.dashboard.history.back_to_history'),
      href: account_history_path,
    )
  end

  it 'renders event rows with non-heading strong titles to avoid a noisy outline' do
    expect(rendered).to have_css('p.ads-history__row-title')
    expect(rendered).to have_no_css('h2.ads-history__row-title, h3.ads-history__row-title')
    expect(rendered).to have_content(t('event_types.sign_in_after_2fa', app_name: APP_NAME))
  end
end
