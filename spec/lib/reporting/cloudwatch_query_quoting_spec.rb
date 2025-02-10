require 'rails_helper'
require 'reporting/cloudwatch_query_quoting'

RSpec.describe Reporting::CloudwatchQueryQuoting do
  subject(:instance) do
    Class.new do
      include Reporting::CloudwatchQueryQuoting
    end.new
  end

  describe '#quote' do
    it 'escapes double quotes in strings' do
      expect(instance.quote('abc "foo" bar')).to eq('"abc \"foo\" bar"')
    end

    it 'quotes arrays' do
      expect(instance.quote(%w[a b c])).to eq('["a","b","c"]')
    end
  end
end
