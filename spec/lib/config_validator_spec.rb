require 'rails_helper'

describe ConfigValidator do
  describe '#validate' do
    let(:env) { {} }

    it 'raises if one or more candidate key values is set to yes or no' do
      env.merge!(
        'bad_key' => 'yes',
        'other_bad_key' => 'no',
        'up_bad_key' => 'YES   ',
        'cap_bad_key' => ' No',
        'noncandidate_key' => 'yes',
      )

      env.delete('noncandidate_key')

      list = 'bad_key, other_bad_key, up_bad_key, and cap_bad_key'

      expect { ConfigValidator.new.validate(env) }.to raise_error(
        RuntimeError,
        %r{You have invalid values \(yes\/no\) for #{list}},
      )
    end
  end
end
