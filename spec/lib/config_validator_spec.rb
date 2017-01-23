require 'rails_helper'

describe ConfigValidator do
  describe '#validate' do
    context 'config/application.yml exists on the server and boolean keys are set to yes or no' do
      it 'raises an error and provides instructions for fixing the keys in the config file' do
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

        error_message = "You have invalid values for #{bad_key} and #{other_bad_key} in " \
                        "config/application.yml. Please change #{bad_key} and #{other_bad_key} " \
                        "to 'true' or 'false'."

        expect { ConfigValidator.new(env).validate }.to raise_error(
          RuntimeError, /#{error_message}/
        )
      end
    end

    context 'application.yml does not exist on the server and boolean keys are set to yes or no' do
      it 'raises an error and provides instructions for fixing boolean keys in the ENV config' do
        allow(File).to receive(:exist?).
          with(Rails.root.join('config/application.yml')).and_return(false)

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

        error_message = "You have invalid values for #{bad_key} and #{other_bad_key} in " \
                        "your ENV configuration. Please change #{bad_key} and #{other_bad_key} " \
                        "to 'true' or 'false'."

        expect { ConfigValidator.new(env).validate }.to raise_error(
          RuntimeError, /#{error_message}/
        )
      end
    end

    context 'keys that should be base64 encoded are not' do
      it 'raises an error and provides instructions for fixing the keys' do
        noncandidate_key = '_FIGARO_attribute_encryption_key'

        env = {
          'attribute_encryption_key' => 'bad_key',
          'email_encryption_key' => 'bad_base64_value',
          noncandidate_key => 'bad_base64_value'
        }

        error_message = 'You have invalid values for attribute_encryption_key ' \
                        'and email_encryption_key in config/application.yml. ' \
                        'Please change attribute_encryption_key and ' \
                        'email_encryption_key to a valid base64 encoded value.'

        expect { ConfigValidator.new(env).validate }.to raise_error(
          RuntimeError, /#{error_message}/
        )
      end
    end

    context 'both bad boolean and bad base64 keys are present' do
      it 'raises an error and provides instructions for fixing both types of keys' do
        noncandidate_key = '_FIGARO_bad_boolean_key'

        env = {
          'attribute_encryption_key' => 'bad_base64_value',
          'bad_boolean_key' => 'yes',
          noncandidate_key => 'yes'
        }

        error_message = "You have invalid values for bad_boolean_key and " \
                        "attribute_encryption_key in config/application.yml. " \
                        "Please change bad_boolean_key to 'true' or 'false'. Please change " \
                        "attribute_encryption_key to a valid base64 encoded value."

        expect { ConfigValidator.new(env).validate }.to raise_error(
          RuntimeError, /#{error_message}/
        )
      end
    end
  end
end
