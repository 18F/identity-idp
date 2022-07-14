require 'rails_helper'

describe 'idv/cancellations/new.html.erb' do
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

  it 'renders action to start over' do
    expect(rendered).to have_button(t('idv.cancel.actions.start_over'))
  end

  it 'renders action to keep going' do
    expect(rendered).to have_text(t('idv.cancel.actions.keep_going'))
  end

  it 'renders action to exit and go to account page' do
    expect(rendered).to have_content(t('idv.cancel.headings.exit.without_sp'))
    t(
      'idv.cancel.description.exit.without_sp',
      app_name: APP_NAME,
      account_page_text: t('idv.cancel.description.account_page'),
    ).each { |expected_p| expect(rendered).to have_content(expected_p) }
    expect(rendered).to have_button(t('idv.cancel.actions.account_page'))
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
        account_page_link: t('idv.cancel.description.account_page'),
      ).each { |expected_p| expect(rendered).to have_content(expected_p) }
      expect(rendered).to have_button(t('idv.cancel.actions.exit', app_name: APP_NAME))
    end
  end
end
