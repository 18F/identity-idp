# frozen_string_literal: true

# Presenter for the account homepage (Accounts::HomeController#show):
# the time-of-day greeting hero, the connected-services section, and the
# curated "More ways to use your account" discovery list with category filter.
class AccountHomePresenter
  include HeaderPersonalization

  # Hour boundaries (inclusive lower bound) for each greeting bucket. The
  # comparison uses `now.hour`, where `now` is Time.zone.now — i.e. the
  # application's configured time zone, NOT the signed-in user's local time.
  # This timezone assumption is asserted in the presenter spec.
  MORNING_ENDS_AT = 12
  AFTERNOON_ENDS_AT = 18

  attr_reader :user, :decrypted_pii, :now

  def initialize(user:, decrypted_pii:, now:, category: nil)
    @user = user
    @decrypted_pii = decrypted_pii
    @now = now
    @category = category
  end

  def greeting
    I18n.t("account.dashboard.greeting.#{time_of_day_bucket}")
  end

  def time_of_day_bucket
    hour = now.hour
    if hour < MORNING_ENDS_AT
      :morning
    elsif hour < AFTERNOON_ENDS_AT
      :afternoon
    else
      :evening
    end
  end

  def connected_apps
    @connected_apps ||=
      user.connected_apps.includes([:service_provider_record, :email_address])
  end

  def connected_apps?
    connected_apps.any?
  end

  # Category filter chips are only shown once the user has at least one
  # connected service (per canonical empty-state frame 11893-26303, which
  # renders the discovery list with no chips).
  def show_filters?
    connected_apps?
  end

  def categories
    FeaturedService.categories
  end

  # Whitelisted, defaulted category slug driven by the ?category= param.
  def selected_category
    slug = @category.to_s
    FeaturedService.category_slugs.include?(slug) ? slug : FeaturedService::ALL_CATEGORY_SLUG
  end

  def category_selected?(slug)
    selected_category == slug
  end

  # Discovery services for the current filter, excluding any agency the user is
  # already connected to (matched by display name). This reproduces the Figma
  # behavior where connected agencies drop out of the discovery list.
  def featured_services
    @featured_services ||= begin
      available = FeaturedService.all.reject do |service|
        connected_service_names.include?(service.name)
      end
      available.select { |service| service.in_category?(selected_category) }
    end
  end

  def featured_services?
    featured_services.any?
  end

  private

  def connected_service_names
    @connected_service_names ||= connected_apps.map(&:display_name).to_set
  end
end
