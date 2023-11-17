require 'rails_helper'

RSpec.describe 'idv/in_person/state_id.html.erb' do
  let(:pii) { {} }
  let(:form) { Idv::StateIdForm.new(pii) }
  let(:parsed_dob) { Date.new(1970, 1, 1) }

  before do
    allow(view).to receive(:url_for).and_return('https://example.com/')
  end

  subject(:render_template) do
    render template: 'idv/in_person/state_id', locals: { updating_state_id: true, form: form, pii: pii, parsed_dob: parsed_dob }
  end

  it 'renders state ID hint text with correct screenreader tags', aggregate_failures: true do
    render_template

    doc = Nokogiri::HTML(rendered)

    jurisdiction_extras = doc.at_css('.jurisdiction-extras')

    all_hints = jurisdiction_extras.css('[data-state]')
    shown = jurisdiction_extras.css('[data-state]:not(.display-none)')
    hidden = jurisdiction_extras.css('[data-state].display-none')

    expect(shown.size).to eq(1), 'only shows one hint'
    expect(shown.size + hidden.size).to eq(all_hints.size)

    default_hint = jurisdiction_extras.at_css('[data-state=default]')
    default_hint_screenreader_tags = default_hint.css('.usa-sr-only')
    *first, last = default_hint_screenreader_tags.map(&:text)
    expect(first).to all end_with(',')
    expect(last).to_not end_with(',')
  end
end
