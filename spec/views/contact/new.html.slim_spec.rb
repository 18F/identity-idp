require 'rails_helper'

describe 'contact/new.html.slim' do
  before do
    @contact_form = ContactForm.new
  end

  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.contact'))

    render
  end

  it 'has a localized header' do
    render

    expect(rendered).to have_selector('h1', text: t('headings.contact'))
  end
end
