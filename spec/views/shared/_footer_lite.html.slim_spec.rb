require 'rails_helper'

describe 'shared/_footer_lite.html.slim' do
  context 'user is signed out' do
    before do
      controller.request.path_parameters[:controller] = 'users/sessions'
      controller.request.path_parameters[:action] = 'new'
    end

    it 'contains link to help page' do
      render

      expect(rendered).to have_link(t('links.help'), href: MarketingSite.help_url)
      expect(rendered).to have_selector("a[href='#{MarketingSite.help_url}'][target='_blank']")
    end

    it 'contains link to contact page' do
      render

      expect(rendered).to have_link(t('links.contact'), href: MarketingSite.contact_url)
      expect(rendered).to have_selector("a[href='#{MarketingSite.contact_url}'][target='_blank']")
    end

    it 'contains link to privacy page' do
      render

      expect(rendered).to have_link(t('links.privacy_policy'), href: MarketingSite.privacy_url)
      expect(rendered).to have_selector("a[href='#{MarketingSite.privacy_url}'][target='_blank']")
    end

    it 'contains GSA text' do
      render

      expect(rendered).to have_content(t('shared.footer_lite.gsa'))
    end
  end
end
