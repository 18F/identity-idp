require 'rails_helper'

describe 'sign_up/registrations/show.html.slim' do
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
      to have_link(t('experiments.demo.get_started'), href: sign_up_email_path)
  end

  context 'when @sp_name is not set' do
    before do
      @sp_name = nil
    end

    it 'includes sp-specific copy' do
      render

      expect(rendered).to have_content(
        t('headings.create_account_without_sp', sp: nil)
      )
      expect(rendered).to have_content(
        t('devise.registrations.start.bullet_1_without_sp', sp: nil)
      )
    end
  end

  context 'when @sp_name is set' do
    before do
      @sp_name = 'Awesome Application!'
    end

    it 'includes sp-specific copy' do
      render

      expect(rendered).to have_content(
        t('headings.create_account_with_sp', sp: @sp_name)
      )
      expect(rendered).to have_content(
        t('devise.registrations.start.bullet_1_with_sp', sp: @sp_name)
      )
    end
  end
end
