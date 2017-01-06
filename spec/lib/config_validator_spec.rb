require 'rails_helper'

describe ConfigValidator do
  describe '#validator' do
    it 'raises if one or more candidate key values is set to yes or no' do
      bad_key = 'bad_key'
      other_bad_key = 'other_bad_key'
      noncandidate_key = '_FIGARO_KEY'
      good_key = 'good_key'

      env = {
        bad_key => 'yes',
        other_bad_key => 'no',
        noncandidate_key => 'yes',
        good_key => 'foo'
      }

      expect { ConfigValidator.new.validate(env) }.to raise_error(
        RuntimeError,
        /You have invalid values for #{bad_key} and #{other_bad_key}/
      )
    end
  end
end
