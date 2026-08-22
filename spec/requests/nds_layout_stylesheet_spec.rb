require 'rails_helper'

RSpec.describe 'NDS layout stylesheet swap', type: :request do
  context 'default bucket' do
    it 'renders the legacy application stylesheet, not nds_application' do
      get root_url

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/application[-.]})
      expect(response.body).not_to include('nds_application')
    end

    it 'preloads public-sans fonts, not inter/InterVariable' do
      get root_url

      expect(response.body).to include('public-sans/PublicSans')
      expect(response.body).not_to include('inter/InterVariable')
    end

    it 'loads the legacy utilities and print bundles, not the nds variants' do
      get root_url

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/utilities[-.]})
      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/print[-.]})
      expect(response.body).not_to include('nds_utilities')
      expect(response.body).not_to include('nds_print')
    end

    it 'renders the legacy page structure (grid-container/card), not the nds shell' do
      get root_url
      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css('.grid-container')).to be_present
      expect(doc.at_css('.auth-page')).to be_nil
      expect(response.body).not_to include('data-nds-page-transition')
    end
  end

  context 'forced nds bucket' do
    it 'renders the nds_application stylesheet via the nds base layout' do
      get root_url, params: { ui_test_bucket: 'nds' }

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/nds_application[-.]})
    end

    it 'preloads inter/InterVariable, not public-sans/PublicSans' do
      get root_url, params: { ui_test_bucket: 'nds' }

      expect(response.body).to include('inter/InterVariable')
      expect(response.body).not_to include('public-sans/PublicSans')
    end

    it 'loads the nds_utilities and nds_print bundles, not the legacy variants' do
      get root_url, params: { ui_test_bucket: 'nds' }

      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/nds_utilities[-.]})
      expect(response.body).to match(%r{stylesheet["'][^>]*/assets/nds_print[-.]})
      expect(response.body).not_to match(%r{stylesheet["'][^>]*/assets/utilities[-.]})
      expect(response.body).not_to match(%r{stylesheet["'][^>]*/assets/print[-.]})
    end

    it 'renders the NDS page shell with the transition attribute on .auth-page' do
      get root_url, params: { ui_test_bucket: 'nds' }
      doc = Nokogiri::HTML(response.body)

      shell = doc.at_css('.auth-page')
      expect(shell).to be_present
      expect(shell.attributes).to have_key('data-nds-page-transition')
      expect(doc.at_css('.auth-page__main#main-content')).to be_present
      expect(doc.at_css('.auth-page__top-chrome')).to be_present
      # nds shell replaces the legacy grid-container/card chrome
      expect(doc.at_css('.grid-container.card')).to be_nil
    end
  end
end
