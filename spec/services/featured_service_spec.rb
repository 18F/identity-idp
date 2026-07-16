# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeaturedService do
  before { described_class.reload! }
  after { described_class.reload! }

  describe '.all' do
    it 'loads every service from config/featured_services.yml' do
      expect(described_class.all.length).to eq(14)
      expect(described_class.all).to all(be_a(described_class))
    end

    it 'exposes the expected attributes for each service' do
      services = described_class.all
      services.each do |service|
        expect(service.key).to be_present
        expect(service.name).to be_present
        expect(service.description_key).to start_with('account.dashboard.discovery.services.')
        expect(service.url).to match(%r{\Ahttps://})
        expect(service.categories).to all(be_in(described_class.categories.map(&:slug)))
      end
    end

    it 'sets a logo only for the agencies with exported artwork' do
      with_logos = described_class.all.select(&:logo?).map(&:key)
      expect(with_logos).to match_array(%w[ssa irs va dol mytravelgov])
    end
  end

  describe '.categories' do
    it 'returns the six filterable categories (excluding the synthetic all)' do
      slugs = described_class.categories.map(&:slug)
      expect(slugs).to eq(
        %w[
          taxes_and_money
          health_and_benefits
          jobs_and_retirement
          travel
          veterans_and_military
          business_and_professional
        ],
      )
      expect(described_class.categories.map(&:label_key)).to all(
        start_with('account.dashboard.discovery.categories.'),
      )
    end
  end

  describe '.category_slugs' do
    it 'includes the all slug plus every category slug' do
      expect(described_class.category_slugs.first).to eq('all')
      expect(described_class.category_slugs).to include('travel', 'taxes_and_money')
    end
  end

  describe '#in_category?' do
    let(:service) do
      described_class.new(
        key: 'x', name: 'X', description_key: 'k', url: 'https://x.gov/',
        categories: ['travel']
      )
    end

    it 'matches the synthetic all slug' do
      expect(service.in_category?('all')).to be(true)
    end

    it 'matches a declared category' do
      expect(service.in_category?('travel')).to be(true)
    end

    it 'does not match an undeclared category' do
      expect(service.in_category?('taxes_and_money')).to be(false)
    end
  end
end
