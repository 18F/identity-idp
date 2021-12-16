require 'rails_helper'

describe 'idv/cancellations/new.html.erb' do
  let(:hybrid_session) { false }
  let(:params) { ActionController::Parameters.new }

  before do
    assign(:hybrid_session, hybrid_session)
    allow(view).to receive(:params).and_return(params)

    render
  end

  it 'renders go back path' do
    expect(rendered).to have_button(t('links.go_back'))
  end

  context 'with hybrid flow' do
    let(:hybrid_session) { true }

    it 'renders heading' do
      expect(rendered).to have_text(t('idv.cancel.headings.prompt.hybrid'))
    end

    it 'renders content' do
      expect(rendered).to have_text(t('idv.cancel.warnings.hybrid'))
    end
  end

  context 'with standard flow' do
    let(:hybrid_session) { false }

    it 'renders heading' do
      expect(rendered).to have_text(t('headings.cancellations.prompt'))
    end

    it 'renders content' do
      expect(rendered).to have_text(t('sign_up.cancel.warning_header'))
    end
  end

  context 'with step parameter' do
    let(:params) { ActionController::Parameters.new(step: 'first') }

    it 'forwards step to confirmation link' do
      expect(rendered).to have_selector(
        "[action='#{idv_cancel_path(step: 'first', location: 'cancel')}']",
      )
      expect(rendered).to have_button(t('forms.buttons.cancel'))
    end
  end
end
