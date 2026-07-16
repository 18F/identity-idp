require 'rails_helper'

RSpec.describe 'partials/personal_key/_key.html.erb' do
  let(:personal_key) { 'abcd-efgh-ijkl-mnop' }
  let(:locals) do
    {
      code: personal_key,
      show_save_buttons: false,
    }
  end

  subject(:rendered) do
    render partial: 'key', locals: locals
  end

  it 'renders the code segments with separators' do
    expect(rendered).to have_content('abcd - efgh - ijkl - mnop')
  end

  context 'with example code' do
    let(:locals) { super().merge(code_example: true) }

    it 'renders code example description' do
      expect(rendered).to have_content(t('users.personal_key.accessible_labels.code_example'))
      expect(rendered).to have_css('[aria-hidden]', text: 'abcd - efgh - ijkl - mnop')
    end
  end

  context 'with local personal_key_generated_at' do
    let(:personal_key_generated_at) { Time.zone.parse('2020-04-09T14:03:00Z').utc }
    let(:locals) { super().merge(personal_key_generated_at: personal_key_generated_at) }

    it 'displays the specified date without time' do
      expect(rendered).to have_content(
        t(
          'forms.personal_key.generated_on',
          date: I18n.l(personal_key_generated_at, format: I18n.t('time.formats.event_date')),
        ),
      )
    end

    it 'displays personal key block' do
      expect(rendered).to have_css('.ads-personal-key-display__code')
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
      expect(rendered).to have_css('.ads-personal-key-display__code')
    end
  end
end
