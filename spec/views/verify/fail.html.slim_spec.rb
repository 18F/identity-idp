require 'rails_helper'

describe 'verify/fail.html.slim' do
  context 'when @sp_name is set' do
    before do
      @sp_name = 'Awesome Application!'
    end

    it 'displays the hardfail4 partial' do
      render

      expect(view).to render_template(partial: 'verify/_hardfail4')
      expect(rendered).to have_content(
        t('idv.messages.hardfail4', sp: @sp_name)
      )
    end
  end

  context 'when @sp_name is not set' do
    before do
      @sp_name = nil
    end

    it 'displays the null partial' do
      render

      expect(view).to render_template(partial: 'shared/_null')
    end
  end
end
