require 'rails_helper'

describe ConfigValidator do
  describe '#validate' do
    let(:env) do
      {
        'phone_proofing_vendor' => 'mock',
        'profile_proofing_vendor' => 'mock',
      }
    end

    it 'raises if one or more candidate key values is set to yes or no' do
      env.merge!(
        'bad_key' => 'yes',
        'other_bad_key' => 'no',
        'up_bad_key' => 'YES   ',
        'cap_bad_key' => ' No',
        'noncandidate_key' => 'yes'
      )

      mimic_figaro
      env.delete(ConfigValidator::ENV_PREFIX + 'noncandidate_key')

      list = 'bad_key, other_bad_key, up_bad_key, and cap_bad_key'

      expect { ConfigValidator.new.validate(env) }.to raise_error(
        RuntimeError,
        %r{You have invalid values \(yes\/no\) for #{list}}
      )
    end

    it 'raises if a non empty key is empty' do
      env.delete('phone_proofing_vendor')
      mimic_figaro

      expect { ConfigValidator.new.validate(env) }.to raise_error(
        RuntimeError,
        'These configs are required and were empty: phone_proofing_vendor'
      )
    end

    def mimic_figaro
      # Figaro sets 2 environment variables for each configuration:
      # 1 with and 1 without the Figaro prefix. Settings that don't
      # have both are not part of the configuration.  This mimics
      # Figaro by adding the settings with the prefix.
      env.dup.each do |key, value|
        env[ConfigValidator::ENV_PREFIX + key] = value
      end
    end
  end
end
