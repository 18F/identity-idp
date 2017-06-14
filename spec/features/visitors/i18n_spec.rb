require 'rails_helper'

feature 'Internationalization' do
  context 'visit homepage' do
    before do
      page.driver.header 'Accept-Language', locale
      visit root_path
    end

    context 'when the user has set their locale to :en' do
      let(:locale) { :en }

      it 'displays a translated header to the user' do
        expect(page).to have_content t('headings.sign_in_without_sp', locale: 'en')
      end
    end

    context 'when the user has set their locale to :es' do
      let(:locale) { :es }

      it 'displays a translated header to the user' do
        expect(page).to have_content t('headings.sign_in_without_sp', locale: 'es')
      end
    end
  end
end
