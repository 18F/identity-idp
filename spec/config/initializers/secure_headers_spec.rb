require 'rails_helper'

RSpec.describe 'config.ssl_options' do
  subject(:ssl_options) { Rails.application.config.ssl_options }

  it 'is configured to use Strict-Transport-Security (HSTS)' do
    basic_app = lambda { |env| [200, {}, []] }
    ssl_middleware = ActionDispatch::SSL.new(basic_app, **ssl_options)

    request = { 'HTTPS' => 'on' }
    _status, headers, _body = ssl_middleware.call(request)

    expect(headers['strict-transport-security']).
      to eq('max-age=31556952; includeSubDomains; preload')
  end
end
