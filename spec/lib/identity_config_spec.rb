require 'rails_helper'

RSpec.describe IdentityConfig do
  let(:default_yaml_config) do
    YAML.safe_load_file(Rails.root.join('config', 'application.yml.default')).freeze
  end

  describe '.key_types' do
    subject(:key_types) { Identity::Hostdata.config_builder.key_types }

    it 'has defaults defined for all keys in default configuration' do
      aggregate_failures do
        key_types.keys.each do |key|
          expect(default_yaml_config)
            .to have_key(key.to_s), "expected default configuration to include value for #{key}"
        end
      end
    end

    it 'has all _enabled keys as booleans' do
      aggregate_failures do
        key_types.select { |key, _type| key.to_s.end_with?('_enabled') }
          .each do |key, type|
            expect(type).to eq(:boolean), "expected #{key} to be a boolean"
          end
      end
    end

    it 'has all _at keys as timestamps' do
      aggregate_failures do
        key_types.select { |key, _type| key.to_s.end_with?('_at') }
          .each do |key, type|
            expect(type).to eq(:timestamp), "expected #{key} to be a timestamp"
          end
      end
    end

    it 'has all _timeout keys as numbers' do
      aggregate_failures do
        key_types.select { |key, _type| key.to_s.end_with?('_timeout') }
          .each do |key, type|
            expect(type).to eq(:float).or(eq(:integer)), "expected #{key} to be a number"
          end
      end
    end
  end

  describe 'idv_contact_phone_number' do
    it 'has config value for contact phone number' do
      contact_number = Identity::Hostdata.config.idv_contact_phone_number

      expect(contact_number).to_not be_empty
      expect(contact_number).to match(/\(\d{3}\)\ \d{3}-\d{4}/)
    end
  end

  describe 'in_person_outage_message_enabled' do
    it 'has valid config values for dates when outage enabled' do
      if Identity::Hostdata.config.in_person_outage_message_enabled
        expect(Identity::Hostdata.config.in_person_outage_expected_update_date).to_not be_empty
        expect(Identity::Hostdata.config.in_person_outage_emailed_by_date).to_not be_empty

        update_date = Identity::Hostdata.config.in_person_outage_expected_update_date.to_date
        update_month, update_day, update_year =
          Identity::Hostdata.config.in_person_outage_expected_update_date.remove(',').split(' ')

        expect(Date::MONTHNAMES.include?(update_month && update_month.capitalize)).to be_truthy
        expect(update_day).to_not be_empty
        expect(update_year).to_not be_empty
        expect { update_date }.to_not raise_error

        email_date = Identity::Hostdata.config.in_person_outage_emailed_by_date.to_date
        email_month, email_day, email_year =
          Identity::Hostdata.config.in_person_outage_emailed_by_date.remove(',').split(' ')

        expect(Date::MONTHNAMES.include?(email_month && email_month.capitalize)).to be_truthy
        expect(email_day).to_not be_empty
        expect(email_year).to_not be_empty
        expect { email_date }.to_not raise_error
      end
    end
  end

  describe '.unused_keys' do
    it 'does not have any unused keys' do
      expect(Identity::Hostdata.config_builder.unused_keys).to be_empty
    end
  end

  describe 'redundant configuration' do
    it 'does not use the default value in development' do
      check_for_default('development')
    end

    it 'does not use the default value in production' do
      check_for_default('production')
    end

    it 'does not use the default value in test' do
      check_for_default('test')
    end

    it 'does not define an identical value in development, production, and test' do
      keys = Identity::Hostdata.config_builder.key_types.map { |key, _type| key.to_s }
      aggregate_failures do
        keys.each do |key|
          expect(
            !default_yaml_config.key?(key) &&
              default_yaml_config['production'].key?(key) &&
              default_yaml_config['production'][key] == default_yaml_config['test'][key] &&
              default_yaml_config['test'][key] == default_yaml_config['development'][key],
          ).to(
            eq(false),
            "#{key} uses the same value in development, production and test instead of a default",
          )
        end
      end
    end
  end

  def check_for_default(env_name)
    aggregate_failures do
      default_yaml_config[env_name].each do |key, value|
        next unless default_yaml_config.key?(key)
        expect(value).to_not(
          eq(default_yaml_config[key]),
          "#{key} in #{env_name} uses the default value",
        )
      end
    end
  end
end
