require 'rails_helper'

RSpec.describe IdentityConfig do
  describe '.key_types' do
    it 'has all _enabled keys as booleans' do
      aggregate_failures do
        IdentityConfig.key_types.select { |key, _type| key.to_s.end_with?('_enabled') }.
          each do |key, type|
            expect(type).to eq(:boolean), "expected #{key} to be a boolean"
          end
      end
    end

    it 'has all _at keys as timestamps' do
      aggregate_failures do
        IdentityConfig.key_types.select { |key, _type| key.to_s.end_with?('_at') }.
          each do |key, type|
            expect(type).to eq(:timestamp), "expected #{key} to be a timestamp"
          end
      end
    end

    it 'has all _timeout keys as numbers' do
      aggregate_failures do
        IdentityConfig.key_types.select { |key, _type| key.to_s.end_with?('_timeout') }.
          each do |key, type|
            expect(type).to eq(:float).or(eq(:integer)), "expected #{key} to be a number"
          end
      end
    end
  end

  describe 'in_person_outage_message_enabled' do
    it 'has valid config values for dates when outage enabled' do
      if IdentityConfig.store.in_person_outage_message_enabled
        expect(IdentityConfig.store.in_person_outage_expected_update_date).to_not be_empty
        expect(IdentityConfig.store.in_person_outage_emailed_by_date).to_not be_empty

        update_date = IdentityConfig.store.in_person_outage_expected_update_date.to_date
        update_month, update_day, update_year =
          IdentityConfig.store.in_person_outage_expected_update_date.remove(',').split(' ')

        expect(Date::MONTHNAMES.include?(update_month && update_month.capitalize)).to be_truthy
        expect(update_day).to_not be_empty
        expect(update_year).to_not be_empty
        expect { update_date }.to_not raise_error

        email_date = IdentityConfig.store.in_person_outage_emailed_by_date.to_date
        email_month, email_day, email_year =
          IdentityConfig.store.in_person_outage_emailed_by_date.remove(',').split(' ')

        expect(Date::MONTHNAMES.include?(email_month && email_month.capitalize)).to be_truthy
        expect(email_day).to_not be_empty
        expect(email_year).to_not be_empty
        expect { email_date }.to_not raise_error
      end
    end
  end
end
