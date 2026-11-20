require 'rails_helper'

RSpec.describe 'events/show.html.erb' do
  let(:user) { create(:user, :fully_registered) }
  let(:device) { create(:device, user:, last_ip: '97.73.13.33') }
  let!(:events) do
    [
      create(:event, user:, device:, event_type: :sign_in_after_2fa, ip: '97.73.13.33'),
      create(:event, user:, device:, event_type: :sign_in_before_2fa, ip: '97.73.13.33'),
    ]
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil,
        user:,
        sp_session_request_url: nil,
        authn_context: nil,
        sp_name: nil,
        locked_for_session: false,
      ),
    )
    assign(:device, device.decorate)
    assign(:events, events.map(&:decorate))
  end

  it 'renders the device events with a back link to the account page' do
    render

    expect(rendered).to have_css('h1', text: t('headings.account.activity'))
    expect(rendered).to have_css('h2', text: device.decorate.nice_name)
    expect(rendered).to have_content(t('event_types.sign_in_after_2fa'))
    expect(rendered).to have_link(t('forms.buttons.back'), href: account_path)
  end

  it 'does not render the NDS history layout in the default layout' do
    render

    expect(rendered).to_not have_css('.history')
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
    end

    it 'renders the device name as the only h1, after a back button to History' do
      render

      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css(
        '.history .history__header h1.history__heading',
        text: device.decorate.nice_name,
      )
      expect(rendered).to have_css(
        ".history__header a.usa-button.usa-button--secondary.usa-button--icon-only.history__back\
[href='#{account_history_path}'][aria-label='#{t('forms.buttons.back')}'] svg.usa-icon",
      )
      expect(rendered).to_not have_css('.card')
      expect(rendered).to_not have_link(href: account_path)
    end

    it 'renders each event as a row with its time and location' do
      render

      expect(rendered).to have_css('.history__panel .history__rows li.history-row', count: 2)
      row = Capybara.string(rendered).find(
        '.history-row',
        text: t('event_types.sign_in_after_2fa'),
      )
      expect(row).to have_css('.history-row__title', text: t('event_types.sign_in_after_2fa'))
      expect(row).to have_css('.history-row__meta lg-time')
      expect(row).to have_css(
        '.history-row__meta',
        text: events.first.decorate.last_sign_in_location_and_ip,
      )
      expect(row).to_not have_css('.history-row__action')
    end

    context 'when the device has no events' do
      before { assign(:events, []) }

      it 'renders the heading without an empty panel' do
        render

        expect(rendered).to have_css('h1', text: device.decorate.nice_name)
        expect(rendered).to_not have_css('.history__panel')
      end
    end
  end
end
