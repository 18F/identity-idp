require 'rails_helper'

describe 'shared/_footer_lite.html.slim' do
  context 'user is signed out' do
    it 'contains link to help page' do
      render

      expect(rendered).to have_link(t('links.help'), href: help_path)
      expect(rendered).to have_selector("a[href='#{help_path}'][target='_blank']")
    end

    it 'contains link to contact page' do
      render

      expect(rendered).to have_link(t('links.contact'), href: contact_path)
      expect(rendered).to have_selector("a[href='#{contact_path}'][target='_blank']")
    end

    it 'contains link to privacy page' do
      render

      expect(rendered).to have_link(t('links.privacy_policy'), href: privacy_path)
      expect(rendered).to have_selector("a[href='#{privacy_path}'][target='_blank']")
    end

    it 'contains GSA text' do
      render

      expect(rendered).to have_content(t('shared.footer_lite.gsa'))
    end
  end
end
