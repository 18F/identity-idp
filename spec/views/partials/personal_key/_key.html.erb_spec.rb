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

  it 'renders the code without whitespace between segments' do
    expect(rendered).to have_content('abcdefghijklmnop')
  end

  context 'with example code' do
    let(:locals) { super().merge(code_example: true) }

    it 'renders code example description' do
      expect(rendered).to have_content(t('users.personal_key.accessible_labels.code_example'))
      expect(rendered).to have_css('[aria-hidden]', text: 'abcdefghijklmnop')
    end
  end

  context 'with local personal_key_generated_at' do
    let(:personal_key_generated_at) { Time.zone.parse('2020-04-09T14:03:00Z').utc }
    let(:locals) { super().merge(personal_key_generated_at: personal_key_generated_at) }

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
