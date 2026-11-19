require 'rails_helper'

RSpec.describe 'idv/cancellations/new.html.erb' do
  let(:hybrid_session) { false }
  let(:params) { ActionController::Parameters.new }
  let(:sp_name) { nil }
  let(:presenter) { Idv::CancellationsPresenter.new(sp_name: sp_name, url_options: {}) }

  before do
    allow(view).to receive(:nds_layout?).and_return(false)
    assign(:hybrid_session, hybrid_session)
    assign(:presenter, presenter)
    allow(view).to receive(:params).and_return(params)
  end

  it 'has the legacy localized title in the default layout' do
    expect(view).to receive(:title=).with(t('titles.idv.cancellation_prompt'))

    render
  end

  context 'in the default layout' do
    before { render }

    it 'renders an action to keep going, with the correct aria attributes' do
      expect(rendered).to have_button_to_with_accessibility(
        t('idv.cancel.actions.keep_going'),
        idv_cancel_path(step: params[:step]),
      )
    end

    it 'renders action to start over, with the correct aria attributes' do
      expect(rendered).to have_button_to_with_accessibility(
        t('idv.cancel.actions.start_over'),
        idv_session_path(step: params[:step]),
      )
    end

    it 'renders action to exit and go to account page, with the correct aria attributes' do
      expect(rendered).to have_content(t('idv.cancel.headings.exit.without_sp'))
      t(
        'idv.cancel.description.exit.without_sp',
        app_name: APP_NAME,
        account_page_text: t('idv.cancel.description.account_page'),
      ).each { |expected_p| expect(rendered).to have_content(expected_p) }

      expect(rendered).to have_button_to_with_accessibility(
        t('idv.cancel.actions.account_page'),
        idv_cancel_path(step: params[:step], location: 'cancel'),
      )
    end

    it 'emits the legacy button classes' do
      expect(rendered).to have_css('.usa-button--big.usa-button--wide')
      expect(rendered).to have_css('.usa-button--outline')
      expect(rendered).not_to have_css('.usa-button--destructive, .usa-button--secondary')
    end

    it 'does not render the NDS form-page card' do
      expect(rendered).to_not have_selector('.auth--form-page')
    end

    context 'with hybrid flow' do
      let(:hybrid_session) { true }

      it 'renders heading' do
        expect(rendered).to have_text(t('idv.cancel.headings.prompt.hybrid'))
      end

      it 'renders content' do
        expect(rendered).to have_text(t('idv.cancel.description.hybrid'))
      end
    end

    context 'with step parameter' do
      let(:params) { ActionController::Parameters.new(step: 'first') }

      it 'forwards step to confirmation link' do
        expect(rendered).to have_selector(
          "[action='#{idv_cancel_path(step: 'first', location: 'cancel')}']",
        )
      end
    end

    context 'with associated sp' do
      let(:sp_name) { 'Example SP' }

      it 'renders action to exit and return to SP' do
        expect(rendered).to have_content(
          t('idv.cancel.headings.exit.with_sp', app_name: APP_NAME, sp_name: sp_name),
        )
        t(
          'idv.cancel.description.exit.with_sp_html',
          app_name: APP_NAME,
          sp_name: sp_name,
          account_page_link_html: t('idv.cancel.description.account_page'),
        ).each { |expected_p| expect(rendered).to have_content(expected_p) }
        expect(rendered).to have_button(t('idv.cancel.actions.exit', app_name: APP_NAME))
      end
    end
  end

  context 'in the NDS layout' do
    before do
      allow(view).to receive(:nds_layout?).and_return(true)
      render
    end

    it 'has a title matching the cancel prompt heading' do
      expect(view.content_for(:title)).to eq(t('idv.cancel.headings.prompt.standard'))
    end

    it 'renders the form-page card with the warning badge and heading' do
      expect(rendered).to have_selector('section.auth.auth--form-page')
      expect(rendered).to have_selector('.nds-status-icon.nds-status-icon--warning')
      expect(rendered).to have_selector('h1', count: 1)
      expect(rendered).to have_selector('h1', text: t('idv.cancel.headings.prompt.standard'))
      expect(rendered).to have_selector('.auth__form-page-body hr.divider')
    end

    it 'renders the start over section with a destructive start over button' do
      expect(rendered).to have_selector('h2', text: t('idv.cancel.headings.start_over'))
      expect(rendered).to have_text(t('idv.cancel.description.start_over'))
      expect(rendered).to have_button_to_with_accessibility(
        t('idv.cancel.actions.start_over'),
        idv_session_path(step: params[:step]),
      )
      expect(rendered).to have_selector(
        "form[action='#{idv_session_path}'] input[name='_method'][value='delete']",
        visible: :all,
      )
      expect(rendered).to have_button(
        t('idv.cancel.actions.start_over'),
        class: 'usa-button--danger',
      )
    end

    it 'renders keep going as a secondary PUT to the cancel path' do
      expect(rendered).to have_button_to_with_accessibility(
        t('idv.cancel.actions.keep_going'),
        idv_cancel_path(step: params[:step]),
      )
      expect(rendered).to have_selector(
        "form[action='#{idv_cancel_path}'] input[name='_method'][value='put']",
        visible: :all,
      )
      expect(rendered).to have_button(
        t('idv.cancel.actions.keep_going'),
        class: 'usa-button--secondary',
      )
    end

    it 'renders the exit section with the waiting spinner button' do
      expect(rendered).to have_selector('h2', text: t('idv.cancel.headings.exit.without_sp'))
      t(
        'idv.cancel.description.exit.without_sp',
        app_name: APP_NAME,
        account_page_text: t('idv.cancel.description.account_page'),
      ).each { |expected_p| expect(rendered).to have_content(expected_p) }
      expect(rendered).to have_button_to_with_accessibility(
        t('idv.cancel.actions.account_page'),
        idv_cancel_path(step: params[:step], location: 'cancel'),
      )
      exit_path = idv_cancel_path(location: 'cancel')
      expect(rendered).to have_selector(
        "lg-spinner-button form[data-form-steps-wait][action='#{exit_path}']",
      )
      expect(rendered).to have_button(
        t('idv.cancel.actions.account_page'),
        class: 'usa-button--secondary',
      )
    end

    it 'does not emit legacy button modifiers' do
      expect(rendered).not_to have_css('.usa-button--big')
      expect(rendered).not_to have_css('.usa-button--outline')
    end

    context 'with step parameter' do
      let(:params) { ActionController::Parameters.new(step: 'first') }

      it 'forwards step to every action' do
        expect(rendered).to have_selector("[action='#{idv_session_path(step: 'first')}']")
        expect(rendered).to have_selector("[action='#{idv_cancel_path(step: 'first')}']")
        expect(rendered).to have_selector(
          "[action='#{idv_cancel_path(step: 'first', location: 'cancel')}']",
        )
      end
    end

    context 'with associated sp' do
      let(:sp_name) { 'Example SP' }

      it 'renders the exit section for the SP with the account page link' do
        expect(rendered).to have_selector(
          'h2',
          text: t('idv.cancel.headings.exit.with_sp', app_name: APP_NAME, sp_name: sp_name),
        )
        expect(rendered).to have_link(t('idv.cancel.description.account_page'), href: account_path)
        expect(rendered).to have_button(t('idv.cancel.actions.exit', app_name: APP_NAME))
      end
    end

    context 'with hybrid flow' do
      let(:hybrid_session) { true }

      it 'has a title matching the hybrid cancel prompt heading' do
        expect(view.content_for(:title)).to eq(t('idv.cancel.headings.prompt.hybrid'))
      end

      it 'renders the hybrid heading and description' do
        expect(rendered).to have_selector('h1', text: t('idv.cancel.headings.prompt.hybrid'))
        expect(rendered).to have_text(t('idv.cancel.description.hybrid'))
        expect(rendered).not_to have_text(t('idv.cancel.headings.start_over'))
      end

      it 'renders a primary cancel DELETE and a tertiary go back PUT' do
        expect(rendered).to have_selector(
          ".auth__actions form[action='#{idv_cancel_path(location: 'cancel')}'] " \
            "input[name='_method'][value='delete']",
          visible: :all,
        )
        expect(rendered).to have_button(t('forms.buttons.cancel'))
        expect(rendered).not_to have_button(
          t('forms.buttons.cancel'),
          class: 'usa-button--tertiary',
        )
        expect(rendered).to have_selector(
          ".auth__actions form[action='#{idv_cancel_path}'] input[name='_method'][value='put']",
          visible: :all,
        )
        expect(rendered).to have_button(t('links.go_back'), class: 'usa-button--tertiary')
      end
    end
  end
end
