require 'rails_helper'

RSpec.describe 'users/webauthn_setup_mismatch/show.html.erb' do
  subject(:rendered) { render }
  let(:configuration) { create(:webauthn_configuration) }
  let(:presenter) { WebauthnSetupMismatchPresenter.new(configuration:) }

  before do
    assign(:presenter, presenter)
  end

  it 'sets title from presenter heading' do
    expect(view).to receive(:title=).with(presenter.heading)

    render
  end

  it 'renders heading from presenter heading' do
    expect(rendered).to have_css('h1', text: presenter.heading)
  end

  it 'renders description from presenter description' do
    expect(rendered).to have_css('p', text: presenter.description)
  end

  it 'renders buttons to continue or undo' do
    expect(rendered).to have_button(t('forms.buttons.continue'))
    expect(rendered).to have_button(t('webauthn_setup_mismatch.undo'))
  end
end
