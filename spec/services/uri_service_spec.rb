require 'rails_helper'

RSpec.describe UriService do
  describe '.params' do
    it 'parses params out as a hash from a URI' do
      uri = 'https://example.com/foo/bar?a=b&c=d'

      params = UriService.params(uri)

      expect(params).to eq('a' => 'b', 'c' => 'd')
      expect(params).to include(a: 'b', c: 'd'), 'also supports indifferent access'
    end
  end

  describe '.add_params' do
    it 'adds params to uris and escapes them correctly' do
      original_uri = 'https://example.com/foo/bar/'
      uri = UriService.add_params(original_uri, query: 'two words')

      expect(uri).to eq('https://example.com/foo/bar/?query=two+words')
    end

    it 'appends to existing query parameters' do
      original_uri = 'https://example.com/foo/bar/?a=b&c=d'
      uri = UriService.add_params(original_uri, e: 'f')

      expect(uri).to eq('https://example.com/foo/bar/?a=b&c=d&e=f')
    end

    it 'returns the original URI when params_to_add is nil' do
      original_uri = 'https://example.com/foo/bar/?a=b'
      uri = UriService.add_params(original_uri, nil)

      expect(uri).to eq('https://example.com/foo/bar/?a=b')
    end

    it 'is nil with a nil uri' do
      uri = UriService.add_params(nil, foo: 'bar')

      expect(uri).to be_nil
    end

    it 'is nil with a blank string uri' do
      uri = UriService.add_params('', foo: 'bar')

      expect(uri).to be_nil
    end

    it 'is nil with a bad uri' do
      uri = UriService.add_params('https://example.com/new.2;;9429"{+![$]`}9839')

      expect(uri).to be_nil
    end

    it 'does not add a trailing question mark when adding empty params' do
      original_uri = 'https://example.com/foo/bar'
      uri = UriService.add_params(original_uri, {})

      expect(uri).to eq('https://example.com/foo/bar')
    end

    it 'handles adding params to a URI with a fragment' do
      original_uri = 'https://example.com/foo/bar/#fragment'
      uri = UriService.add_params(original_uri, query: 'value')

      expect(uri).to eq('https://example.com/foo/bar/?query=value#fragment')
    end
  end
end
