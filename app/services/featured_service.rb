# frozen_string_literal: true

# Plain Ruby object that loads and validates the curated discovery catalog in
# config/featured_services.yml. Backs the "More ways to use your account"
# section rendered by Accounts::HomeController. No database, no external calls.
class FeaturedService
  CONFIG_PATH = Rails.root.join('config', 'featured_services.yml').freeze

  # Slug used for the default "All services" filter chip. Not present in the
  # YAML categories list because it is not a real category, just "no filter".
  ALL_CATEGORY_SLUG = 'all'

  Category = Struct.new(:slug, :label_key, keyword_init: true)

  class InvalidCatalogError < StandardError; end

  attr_reader :key, :name, :description_key, :url, :logo, :categories

  def initialize(key:, name:, description_key:, url:, categories:, logo: nil)
    @key = key
    @name = name
    @description_key = description_key
    @url = url
    @categories = Array(categories)
    @logo = logo
  end

  def logo?
    logo.present?
  end

  def in_category?(slug)
    slug == ALL_CATEGORY_SLUG || categories.include?(slug)
  end

  class << self
    def all
      catalog[:services]
    end

    # Real, filterable categories (excludes the synthetic "all" slug).
    def categories
      catalog[:categories]
    end

    # Valid values for the ?category= param, including the "all" default.
    def category_slugs
      [ALL_CATEGORY_SLUG, *categories.map(&:slug)]
    end

    def reload!
      @catalog = nil
      catalog
    end

    private

    def catalog
      @catalog ||= build_catalog
    end

    def build_catalog
      raw = YAML.safe_load(CONFIG_PATH.read, symbolize_names: true)

      categories = build_categories(raw[:categories])
      valid_slugs = categories.map(&:slug)
      services = build_services(raw[:services], valid_slugs)

      { categories: categories.freeze, services: services.freeze }
    end

    def build_categories(rows)
      Array(rows).map do |row|
        slug = row[:slug].to_s
        label_key = row[:label_key].to_s
        if slug.empty? || label_key.empty?
          raise InvalidCatalogError, "category missing slug or label_key: #{row.inspect}"
        end

        Category.new(slug:, label_key:)
      end
    end

    def build_services(rows, valid_slugs)
      Array(rows).map do |row|
        service = new(
          key: row[:key],
          name: row[:name],
          description_key: row[:description_key],
          url: row[:url],
          logo: row[:logo],
          categories: Array(row[:categories]).map(&:to_s),
        )
        validate_service!(service, valid_slugs)
        service
      end
    end

    def validate_service!(service, valid_slugs)
      %i[key name description_key url].each do |attr|
        if service.public_send(attr).blank?
          raise InvalidCatalogError, "featured service missing #{attr}: #{service.inspect}"
        end
      end

      if service.categories.empty?
        raise InvalidCatalogError, "featured service #{service.key} has no categories"
      end

      unknown = service.categories - valid_slugs
      if unknown.any?
        raise InvalidCatalogError,
              "featured service #{service.key} references unknown categories: #{unknown.inspect}"
      end
    end
  end
end
