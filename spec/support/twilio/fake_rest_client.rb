module Twilio
  class FakeRestClient
    HttpClient = Struct.new(:adapter, :last_request)
    LastRequest = Struct.new(:url, :params, :headers, :method)

    def initialize(*args); end

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
