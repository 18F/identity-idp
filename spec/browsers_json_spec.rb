require 'rails_helper'

RSpec.describe 'browsers.json' do
  before(:all) { system 'make browsers.json' }

  subject(:browsers_json) { JSON.parse(File.read(Rails.root.join('browsers.json'))) }

  it 'includes only keys known to BrowserSupport' do
    actual_keys = browsers_json.map { |entry| entry.split(' ', 2).first }
    known_keys = BrowserSupport::BROWSERSLIST_TO_BROWSER_MAP.keys.map(&:to_s)

    expect(actual_keys - known_keys).to be_empty
  end
end
