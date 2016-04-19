require 'spec_helper'

describe 'Routes', type: :routing do
  before do
    Rails.application.reload_routes!
  end

  it 'routes /terms to TermsController' do
    expect(get: 'terms').to route_to(controller: 'terms', action: 'index')
  end
end
