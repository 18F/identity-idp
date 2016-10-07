require 'rails_helper'

describe FigaroYamlValidator do
  describe '#validator' do
    it 'raises if one or more values / nested values is set to yes or no' do
      yaml = FigaroYamlValidator::FIGARO_YAML
      test_key = 'test_key'
      other_test_key = 'other_test_key'
      third_test_key = 'third_test_key'
      yaml.merge!(
        test_key => 'yes',
        other_test_key => 'no',
        'blah' => { third_test_key => 'yes' }
      )

      expect { FigaroYamlValidator.new.validate(yaml) }.to raise_error(
        RuntimeError,
        /You have invalid values for #{test_key}, #{other_test_key}, and #{third_test_key}/
      )
    end
  end
end
