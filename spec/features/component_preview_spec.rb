require 'rails_helper'

RSpec.describe 'Component preview', :js do
  it 'loads and initializes stylesheets and javascript' do
    visit Lookbook::Engine.routes.url_helpers.lookbook_preview_path('one_time_code_input/preview')

    # This spec loads a preview for a component which is expected to load its own component-specific
    # JavaScript and stylesheet.
    expect(page).to have_css('link[href*="/one_time_code_input_component-"]', visible: false)
    expect(page).to have_css('script[src$="/one_time_code_input_component.js"]', visible: false)

    # The component-specific JavaScript for this component is expected to create a hidden input, so
    # assert that the element is created.
    expect(page).to have_css('[type="hidden"]', visible: false)
  end
end
