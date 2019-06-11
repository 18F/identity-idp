module Twilio
  class FakeRestClient
    HttpClient = Struct.new(:adapter, :last_request)
    LastRequest = Struct.new(:url, :params, :headers, :method)

    def initialize(_username, _password, _account_sid, _region, _http_client); end

    def messages
      FakeMessage
    end

    def calls
      FakeCall
    end

    def http_client
      HttpClient.new('foo', LastRequest.new('foo', {}, {}, 'get'))
    end
  end
end
