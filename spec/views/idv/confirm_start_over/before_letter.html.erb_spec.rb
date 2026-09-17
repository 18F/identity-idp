require 'rails_helper'

RSpec.describe 'idv/confirm_start_over/before_letter.html.erb' do
  let(:nds_layout) { false }

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:go_back_path).and_return(nil)
    @step_indicator_step = :verify_address

    render
  end

  it 'renders the heading and legacy continue button' do
    expect(rendered).to have_css('h1', text: t('idv.cancel.headings.prompt.start_over'))
    expect(rendered).to have_button(t('idv.buttons.continue_plain'))
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'renders a destructive cancel-verification action posting a delete' do
      expect(rendered).to have_css(
        '.auth__actions button.usa-button--danger[type=submit]',
        text: t('nds.errors.cancel_verification'),
      )
      form_selector = "form[action='#{idv_session_path(step: :request_letter)}']"
      expect(rendered).to have_css(
        "#{form_selector} input[name=_method][value=delete]",
        visible: :all,
      )
      expect(rendered).not_to have_button(t('idv.buttons.continue_plain'))
    end

    it 'renders a secondary back action to the fallback path without the legacy back link' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button--secondary[href='#{idv_request_letter_path}']",
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
