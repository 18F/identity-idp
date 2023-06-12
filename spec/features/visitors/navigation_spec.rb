require 'rails_helper'

RSpec.feature 'Navigation links' do
  scenario 'view navigation links' do
    visit root_path
  end
end
