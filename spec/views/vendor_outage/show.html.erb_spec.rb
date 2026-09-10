require 'rails_helper'

RSpec.describe 'vendor_outage/show.html.erb' do
  let(:show_gpo_option) { false }
  let(:nds_layout) { false }

  subject(:rendered) { render }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    @show_gpo_option = show_gpo_option
  end

  it 'does not render gpo option' do
    expect(rendered).not_to have_link(t('idv.troubleshooting.options.verify_by_mail'))
  end

  context 'gpo option shown' do
    let(:show_gpo_option) { true }

    it 'renders gpo option' do
      expect(rendered).to have_link(t('idv.troubleshooting.options.verify_by_mail'))
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders the status page as a secondary option and support as tertiary' do
      expect(rendered).to have_css('.auth--form-page h1', text: t('vendor_outage.working'))
      expect(rendered).to have_css(
        '.nds-troubleshooting-options a.usa-button--secondary[target=_blank]',
        text: t('vendor_outage.get_updates_on_status_page'),
      )
      expect(rendered).to have_css(
        '.nds-troubleshooting-options a.usa-button--tertiary[target=_blank]',
        text: t('idv.troubleshooting.options.contact_support', app_name: APP_NAME),
      )
    end

    it 'omits the divider when there is no outage message' do
      expect(rendered).not_to have_css('hr.divider')
    end

    context 'with an outage message' do
      before { @specific_message = 'Outage details' }

      it 'renders the message and a divider' do
        expect(rendered).to have_css('.auth__form-page-body p', text: 'Outage details')
        expect(rendered).to have_css('hr.divider')
      end
    end

    it 'does not render a back link without a referer' do
      expect(rendered).not_to have_link(t('forms.buttons.back'))
    end

    context 'with a go-back path' do
      before { allow(view).to receive(:go_back_path).and_return('/verify') }

      it 'renders a tertiary back button' do
        expect(rendered).to have_link(t('forms.buttons.back'), href: '/verify')
      end
    end

    context 'gpo option shown' do
      let(:show_gpo_option) { true }

      it 'renders the verify-by-mail option as a tertiary button' do
        expect(rendered).to have_css(
          '.nds-troubleshooting-options a.usa-button--tertiary',
          text: t('idv.troubleshooting.options.verify_by_mail'),
        )
      end
    end
  end
end
