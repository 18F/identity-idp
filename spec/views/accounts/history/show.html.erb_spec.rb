require 'rails_helper'

RSpec.describe 'accounts/history/show.html.erb' do
  let(:user) { create(:user, :fully_registered, :with_personal_key) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    allow(view).to receive(:current_user).and_return(user)
    assign(
      :presenter,
      AccountShowPresenter.new(
        decrypted_pii: nil,
        user: user,
        sp_session_request_url: nil,
        authn_context: nil,
        sp_name: nil,
        locked_for_session: false,
      ),
    )
  end

  it 'contains account history' do
    render

    expect(rendered).to have_content t('account.navigation.history')
    expect(rendered).to have_content t('headings.account.activity')
  end

  it 'does not render the NDS history layout in the default layout' do
    render

    expect(rendered).to_not have_css('.history')
    expect(rendered).to_not have_content(t('nds.dashboard_history.log_out_all_devices'))
  end

  context 'in the NDS layout' do
    let(:device) do
      create(
        :device,
        user:,
        last_ip: '97.73.13.33',
        user_agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 ' \
                    '(KHTML, like Gecko) Version/17.0 Safari/605.1.15',
      )
    end
    let(:service_provider) do
      create(:service_provider, friendly_name: 'Test Agency', return_to_sp_url: 'https://example.com/')
    end

    let(:sign_in_event) do
      create(:event, user:, device:, event_type: :sign_in_after_2fa, ip: '97.73.13.33')
    end

    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      sign_in_event
      create(:event, user:, device:, event_type: :account_created)
      create(
        :service_provider_identity,
        :active,
        user:,
        service_provider_record: service_provider,
      )
    end

    it 'renders one visually hidden h1 and the Devices and Activity sections' do
      render

      expect(rendered).to have_css('h1', count: 1)
      expect(rendered).to have_css('h1.usa-sr-only', text: t('account.navigation.history'))
      expect(rendered).to have_css(
        '.history .history__section h2.history__heading',
        text: t('headings.account.devices'),
      )
      expect(rendered).to have_css(
        '.history .history__section h2.history__heading',
        text: t('headings.account.activity'),
      )
      expect(rendered).to_not have_css('.card')
    end

    it 'links the Devices header button to the log out of all devices page' do
      render

      expect(rendered).to have_css(
        ".history__header a.usa-button.usa-button--secondary.history__header-action\
[href='#{forget_all_browsers_path}']",
        text: t('nds.dashboard_history.log_out_all_devices'),
      )
    end

    it 'renders each device as a row that links to its details' do
      render

      row = Capybara.string(rendered).find(
        '.history__rows .history-row',
        text: device.decorate.nice_name,
      )
      expect(row).to have_css('.history-row__title', text: device.decorate.nice_name)
      expect(row).to have_css(
        '.history-row__meta',
        text: device.decorate.last_sign_in_location_and_ip,
      )
      expect(row).to have_css('.history-row__meta lg-time')
      link = row.find(
        "a.usa-button.usa-button--tertiary.history-row__action" \
        "[href='#{account_events_path(id: device.id)}']",
      )
      expect(link).to have_css(
        '.history-row__action-label',
        text: t('nds.dashboard_history.details'),
      )
      expect(link).to have_css('.usa-sr-only', text: device.decorate.nice_name)
      expect(link).to have_css('.history-row__action-icon svg.usa-icon[aria-hidden="true"]')
    end

    it 'renders each event as a row with its time and location' do
      render

      row = Capybara.string(rendered).find(
        '.history-row',
        text: t('event_types.sign_in_after_2fa'),
      )
      expect(row).to have_css('.history-row__meta', count: 2)
      expect(row).to have_css(
        '.history-row__meta',
        text: sign_in_event.decorate.last_sign_in_location_and_ip,
      )
      expect(row).to_not have_css('.history-row__action')
    end

    it 'leaves out the location line for an event without an IP address' do
      render

      row = Capybara.string(rendered).find('.history-row', text: t('event_types.account_created'))
      expect(row).to have_css('.history-row__meta', count: 1)
    end

    it 'renders a signed-in agency with a link back to it' do
      render

      expect(rendered).to have_css(
        '.history-row__title',
        text: t('nds.dashboard_history.signed_in_with', service_provider: 'Test Agency'),
      )
      expect(rendered).to have_css(
        ".history-row__title a.link[href='https://example.com/']",
        text: 'Test Agency',
      )
    end

    context 'with no devices or activity' do
      before do
        allow(user).to receive(:recent_devices).and_return([])
        allow(user).to receive(:recent_events).and_return([])
      end

      it 'renders the section headings without empty panels' do
        render

        expect(rendered).to have_css('h2', text: t('headings.account.devices'))
        expect(rendered).to have_css('h2', text: t('headings.account.activity'))
        expect(rendered).to_not have_css('.history__panel')
      end
    end

    context 'when the agency has no return URL' do
      let(:service_provider) do
        create(:service_provider, friendly_name: 'Test Agency', return_to_sp_url: nil)
      end

      it 'names the agency without a link' do
        render

        expect(rendered).to have_css(
          '.history-row__title',
          text: t('nds.dashboard_history.signed_in_with', service_provider: 'Test Agency'),
        )
        expect(rendered).to_not have_link('Test Agency')
      end
    end
  end
end
