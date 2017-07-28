require 'rails_helper'

describe ConfigValidator do
  describe '#validator' do
    it 'raises if one or more candidate key values is set to yes or no' do
      bad_key = 'bad_key'
      other_bad_key = 'other_bad_key'
      up_bad_key = 'up_bad_key'
      cap_bad_key = 'cap_bad_key'
      noncandidate_key = 'KEY'
      good_key = 'good_key'

      env = {
        bad_key => 'yes',
        other_bad_key => 'no',
        up_bad_key => 'YES   ',
        cap_bad_key => ' No',
        noncandidate_key => 'yes',
        good_key => 'foo',
      }

      # Figaro sets 2 environment variables for each configuration:
      # 1 with and 1 without the Figaro prefix. Settings that don't
      # have both are not part of the configuration.  This mimics
      # Figaro by adding the settings with the prefix.

      [bad_key, other_bad_key, up_bad_key, cap_bad_key, good_key].each do |key|
        env[ConfigValidator::ENV_PREFIX + key] = env[key]
      end

      list = "#{bad_key}, #{other_bad_key}, #{up_bad_key}, and #{cap_bad_key}"

      expect { ConfigValidator.new.validate(env) }.to raise_error(
        RuntimeError,
        %r{You have invalid values \(yes\/no\) for #{list}}
      )
    end
  end
end
