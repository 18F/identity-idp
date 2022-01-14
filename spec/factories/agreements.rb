FactoryBot.define do
  factory :partner_account_status, class: Agreements::PartnerAccountStatus do
    name { Faker::Types.rb_string(words: 2) }
    order { Faker::Types.rb_integer(to: 1_000_000) }
  end

  factory :partner_account, class: Agreements::PartnerAccount do
    agency
    partner_account_status

    # wanted to use Faker::Space.agency but there aren't enough options to avoid
    # collisions
    name { Faker::Types.rb_string(words: 3).split(' ').map(&:capitalize).join(' ') }
    requesting_agency { "#{agency.abbreviation}-#{Faker::Name.initials(number: 3)}" }
  end

  factory :iaa_gtc, class: Agreements::IaaGtc do
    partner_account

    gtc_number { "LG#{Faker::Name.initials(number: 3)}FY210001" }
    start_date { Time.zone.today }
    end_date { Time.zone.today + 5.years }
  end

  factory :iaa_order, class: Agreements::IaaOrder do
    iaa_gtc

    order_number { Faker::Types.rb_integer(to: 1000) }
    start_date { Time.zone.today }
    end_date { Time.zone.today + 1.year }
  end

  factory :integration_status, class: Agreements::IntegrationStatus do
    name { Faker::Types.rb_string(words: 2) }
    order { Faker::Types.rb_integer(to: 1_000_000) }
  end

  factory :integration, class: Agreements::Integration do
    partner_account
    integration_status
    service_provider

    issuer { service_provider.issuer }
    name { Faker::Types.rb_string(words: 2) }
  end

  factory :integration_usage, class: Agreements::IntegrationUsage do
    iaa_order
    integration { association :integration, partner_account: iaa_order.partner_account }
  end
end
