require 'rails_helper'

describe 'partials/personal_key/_key.html.erb' do
  subject(:rendered) do
    render partial: 'key', locals: locals
  end

  let(:personal_key) { 'XXXX-XXXX-XXXX-XXXX' }

  context 'with local personal_key_generated_at' do
    let(:personal_key_generated_at) { Time.zone.parse('2020-04-09T14:03:00Z').utc }
    let(:locals) do
      {
        code: personal_key,
        personal_key_generated_at: personal_key_generated_at,
        show_save_buttons: false,
      }
    end

    it 'displays the specified date' do
      expect(rendered).to have_css(
        'lg-time[data-timestamp="2020-04-09T14:03:00Z"][data-format]',
        text: 'April 9, 2020 at 2:03 PM',
      )
    end

    it 'displays personal key block' do
      expect(rendered).to have_css('.personal-key-block__code')
    end
  end

  context 'without local personal_key_generated_at' do
    let(:locals) do
      {
        code: personal_key,
        show_save_buttons: false,
      }
    end

    it 'displays personal key block' do
      expect(rendered).to have_css('.personal-key-block__code')
    end
  end
end
