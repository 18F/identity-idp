require 'rails_helper'

feature 'JavaScript progressive enhancement' do
  describe 'banner' do
    context 'javascript disabled' do
      it 'displays content visibly' do
        visit root_path

        expect(page).to have_css('#gov-banner', visible: true)
      end
    end

    context 'javascript enabled', js: true do
      it 'toggles content hidden' do
        visit root_path

        expect(page).to have_css('#gov-banner', visible: :hidden)

        click_on t('shared.banner.how')

        expect(page).to have_css('#gov-banner', visible: true)
      end
    end
  end
end
