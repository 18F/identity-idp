require 'rails_helper'

RSpec.describe 'idv/cancellations/new.html.erb' do
  let(:hybrid_session) { false }
  let(:params) { ActionController::Parameters.new }

  before do
    assign(:hybrid_session, hybrid_session)
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

  it 'renders start over description' do
    expect(rendered).to have_content(t('idv.cancel.description.start_over'))
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

    it 'forwards step to start over and keep going actions' do
      expect(rendered).to have_selector(
        "[action='#{idv_session_path(step: 'first')}']",
      )
      expect(rendered).to have_selector(
        "[action='#{idv_cancel_path(step: 'first')}']",
      )
    end
  end
end
