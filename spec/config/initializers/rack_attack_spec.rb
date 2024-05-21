require 'rails_helper'

RSpec.describe Rack::Attack do
  it 'has the correct number of paths in the path constants' do
    expect(Rack::Attack::EMAIL_REGISTRATION_PATHS.count).to eq(I18n.available_locales.count + 1)
    expect(Rack::Attack::SIGN_IN_PATHS.count).to eq(I18n.available_locales.count + 1)
  end
end
