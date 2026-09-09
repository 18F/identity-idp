require 'rails_helper'

RSpec.describe 'idv/confirm_start_over/index.html.erb' do
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:go_back_path).and_return(nil)
    @step_indicator_step = :verify_address

    render
  end

  it 'renders the heading and legacy continue button' do
    expect(rendered).to have_css('h1', text: t('idv.cancel.headings.prompt.standard'))
    expect(rendered).to have_button(t('idv.buttons.continue_plain'))
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders a destructive cancel-verification action posting a delete' do
      expect(rendered).to have_css(
        '.auth__actions button.usa-button--danger[type=submit]',
        text: t('nds.errors.cancel_verification'),
      )
      expect(rendered).to have_css(
        "form[action='#{idv_session_path(step: :gpo_verify)}'] input[name=_method][value=delete]",
        visible: :all,
      )
      expect(rendered).not_to have_button(t('idv.buttons.continue_plain'))
    end

    it 'renders left-aligned warning bullets with the reworded start-over copy' do
      expect(rendered).to have_css('ul.usa-list.text-left li', count: 2)
      expect(rendered).to have_css('li', text: t('nds.errors.start_over_warning'))
    end

    it 'renders a secondary back action to the fallback path without the legacy back link' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--secondary[href='#{idv_verify_by_mail_enter_code_path}']",
        text: t('forms.buttons.back'),
      )
      expect(rendered).not_to have_css('.border-top')
    end

    context 'with a go-back path' do
      before do
        allow(view).to receive(:go_back_path).and_return('/previous')
        render
      end

      it 'uses the referer for the back action' do
        expect(rendered).to have_link(t('forms.buttons.back'), href: '/previous')
      end
    end
  end
end
