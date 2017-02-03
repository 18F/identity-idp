require 'rails_helper'

describe 'shared/_nav_branded.html.slim' do
  context 'with a SP-logo configured' do
    before do
      @sp_logo = 'generic.svg'
      @sp_name = 'Best SP ever'
      render
    end

    it 'displays the SP logo' do
      expect(rendered).to have_css("img[alt*='Best SP ever']")
    end
  end

  context 'without a SP-logo configured' do
    before do
      @sp_logo = nil
      @sp_name = 'Best SP ever'
      render
    end

    it 'does not display the SP logo' do
      expect(rendered).to_not have_css("img[alt*='Best SP ever']")
    end
  end
end
