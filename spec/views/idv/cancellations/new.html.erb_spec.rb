require 'rails_helper'

RSpec.describe 'idv/cancellations/new.html.erb' do
  let(:hybrid_session) { false }
  let(:params) { ActionController::Parameters.new }
  let(:sp_name) { nil }
  let(:presenter) { Idv::CancellationsPresenter.new(sp_name: sp_name, url_options: {}) }

  before do
    assign(:hybrid_session, hybrid_session)
    assign(:presenter, presenter)
    allow(view).to receive(:params).and_return(params)

    render
  end

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

RSpec.describe 'idv/cancellations/new.html.erb bucket-conditional buttons' do
  let(:params) { ActionController::Parameters.new }

  def render_bucket(nds:)
    assign(:hybrid_session, false)
    assign(:presenter, Idv::CancellationsPresenter.new(sp_name: nil, url_options: {}))
    allow(view).to receive(:params).and_return(params)
    allow(view).to receive(:nds_layout?).and_return(nds)
    render template: 'idv/cancellations/new'
  end

  it 'legacy bucket emits origin/main classes, no nds variant modifiers' do
    render_bucket(nds: false)
    expect(rendered).to have_css('.usa-button--big.usa-button--wide')
    expect(rendered).to have_css('.usa-button--outline')
    expect(rendered).not_to have_css('.usa-button--destructive, .usa-button--secondary')
  end

  it 'nds bucket emits start_over=destructive (--danger) and keep_going=secondary' do
    render_bucket(nds: true)
    expect(rendered).to have_css('.usa-button--danger')
    expect(rendered).to have_css('.usa-button--secondary')
    expect(rendered).not_to have_css('.usa-button--big')
    expect(rendered).not_to have_css('.usa-button--outline')
  end
end
