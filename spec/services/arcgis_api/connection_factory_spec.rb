require 'rails_helper'
RSpec.describe ArcgisApi::ConnectionFactory do
  let(:subject) { described_class.new }

  context 'Create new connection' do
    it 'create connection successfully' do
      test_message = 'This is a test'
      test_response = <<-BODY
        {
          "message": "#{test_message}"
        }     
      BODY
      stub_request(:get, 'https://google.com/').
        with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent' => 'Faraday v2.7.4',
          },
        ).
        to_return(status: 200, body: test_response, headers: {content_type: 'application/json'})

      conn = subject.connection do |con|
        expect(con).to be_instance_of(Faraday::Connection)
      end

      res = conn.get('https://google.com') do |req|
        req.options.context = { service_name: 'arcgis_geocoder_suggest' }
      end
      expect(res.body.fetch('message')).to eq(test_message)
    end
  end
end
