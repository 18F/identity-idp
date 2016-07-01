require 'rails_helper'

describe 'devise/registrations/start.html.slim' do
  it 'has a localized title' do
    expect(view).to receive(:title).with(t('titles.registrations.start'))

    render
  end

  it 'calls the "demo" A/B test' do
    expect(view).to receive(:ab_test).with(:demo)

    render
  end

  it 'includes a link to create a new account' do
    render

    expect(rendered).
      to have_link(t('experiments.demo.get_started'), href: new_user_registration_path)
  end
end
