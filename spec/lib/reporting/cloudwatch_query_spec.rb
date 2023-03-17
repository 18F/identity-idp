require 'rails_helper'
require 'reporting/cloudwatch_query'

RSpec.describe Reporting::CloudwatchQuery do
  subject(:query) { Reporting::CloudwatchQuery.new }

  describe '#to_query' do
    subject(:query) do
      Reporting::CloudwatchQuery.new(
        names: ['Sign In', 'Sign Out'],
        service_provider: 'example:sp:service',
        limit: 5555,
      )
    end

    it 'builds a Cloudwatch Insights query' do
      expect(query.to_query).to eq <<~QUERY.chomp
        fields @message, @timestamp
        | filter properties.service_provider = "example:sp:service"
        | filter name in ["Sign In","Sign Out"]
        | limit 5555
      QUERY
    end
  end

  describe '#quote' do
    it 'escapes double quotes in strings' do
      expect(query.quote('abc "foo" bar')).to eq('"abc \"foo\" bar"')
    end

    it 'quotes arrays' do
      expect(query.quote(%w[a b c])).to eq('["a","b","c"]')
    end
  end
end
