require 'rails_helper'

RSpec.describe 'idv/by_mail/resend_letter/new.html.erb' do
  let(:nds_layout) { false }
  let(:go_back_path) { nil }
  let(:help_center_url) do
    help_center_redirect_url(
      category: 'verify-your-identity',
      article: 'verify-your-address-by-mail',
      flow: :idv,
      step: :gpo_send_letter,
    )
  end

  before do
    allow(view).to receive(:nds_layout?).and_return(nds_layout)
    allow(view).to receive(:go_back_path).and_return(go_back_path)
    allow(view).to receive(:step_indicator_steps)
      .and_return(Idv::StepIndicatorConcern::STEP_INDICATOR_STEPS_GPO)

    render
  end

  it 'has the legacy localized title in the default layout' do
    expect(view.content_for(:title)).to eq(t('titles.idv.get_letter'))
  end

  context 'in the default layout' do
    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    it 'renders the request another letter page' do
      expect(rendered).to have_css('h1', text: t('idv.gpo.request_another_letter.title'))
      expect(rendered).to have_link(
        t('idv.gpo.request_another_letter.learn_more_link'),
        href: help_center_url,
      )
      expect(rendered).to have_button(t('idv.gpo.request_another_letter.button'))
      expect(rendered).to have_css(
        "form[action='#{idv_resend_letter_path}'] input[name='_method'][value='put']", visible: :all
      )
      expect(rendered).to have_link(
        '‹ ' + t('forms.buttons.back'),
        href: idv_verify_by_mail_enter_code_url,
      )
    end
  end

  context 'in the NDS layout' do
    let(:nds_layout) { true }

    it 'has a title matching the request another letter heading' do
      expect(view.content_for(:title)).to eq(t('idv.gpo.request_another_letter.title'))
    end

    it 'renders the form-page card with the heading and instructions' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_css(
        '.auth--form-page h1',
        text: t('idv.gpo.request_another_letter.title'),
      )
      expect(rendered).to have_css(
        '.auth__intro-description',
        text: strip_tags(t('idv.gpo.request_another_letter.instructions_html')),
      )
    end

    it 'pins the progress to the enter password substep, matching the letter enqueued page' do
      expect(view.content_for(:nds_header_progress)).to have_css(
        'nds-progress .progress__step[aria-current="step"] .progress__step-counter',
        text: '10 / 12',
      )
      expect(view.content_for(:pre_flash_content)).to be_nil
    end

    it 'links to the help center in a new tab' do
      expect(rendered).to have_css(
        ".auth__intro-description a[href='#{help_center_url}'][target='_blank']",
        text: t('idv.gpo.request_another_letter.learn_more_link'),
      )
    end

    it 'puts to the resend letter path' do
      expect(rendered).to have_css(
        "form[action='#{idv_resend_letter_path}'] input[name='_method'][value='put']",
        visible: :all,
      )
      expect(rendered).to have_button(t('idv.gpo.request_another_letter.button'))
    end

    it 'goes back to the enter code page' do
      expect(rendered).to have_css(
        ".auth__actions a.usa-button[href='#{idv_verify_by_mail_enter_code_url}']",
        text: t('forms.buttons.back'),
      )
    end

    context 'with a page to go back to' do
      let(:go_back_path) { account_path }

      it 'goes back to the previous page' do
        expect(rendered).to have_css(
          ".auth__actions a.usa-button[href='#{account_path}']",
          text: t('forms.buttons.back'),
        )
      end
    end
  end
end
