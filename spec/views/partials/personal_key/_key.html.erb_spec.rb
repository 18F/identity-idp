require 'rails_helper'

describe 'partials/personal_key/_key.html.erb' do
  subject(:rendered) do
    render partial: 'key', locals: locals
  end

  let(:personal_key) { 'XXXX-XXXX-XXXX-XXXX' }

  context 'with local personal_key_generated_at' do
    let(:personal_key_generated_at) { 5.days.ago }
    let(:locals) do
      {
        code: personal_key,
        personal_key_generated_at: personal_key_generated_at,
        show_save_buttons: false,
      }
    end

    it 'displays the specified date' do
      expect(rendered).to have_content(
        t(
          'users.personal_key.generated_on_html',
          date: I18n.l(personal_key_generated_at, format: '%B %d, %Y'),
        ),
      )
    end
  end

  context 'without local personal_key_generated_at' do
    let(:locals) do
      {
        code: personal_key,
        show_save_buttons: false,
      }
    end

    it 'displays todays date' do
      expect(rendered).to have_content(
        t(
          'users.personal_key.generated_on_html',
          date: I18n.l(Time.zone.today, format: '%B %d, %Y'),
        ),
      )
    end
  end
end
