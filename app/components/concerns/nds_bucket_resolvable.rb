# frozen_string_literal: true

# Shared render-time A/B bucket resolution for components that have an NDS
# variant. The bucket can only be resolved at render time (helpers are
# unavailable in #initialize). Callers always instantiate the base component
# (or one of its non-NDS subclasses); when the render resolves to the NDS
# bucket we delegate to the variant returned by #nds_delegate, which renders
# itself with the NDS markup. The guard excludes the NDS variant class itself
# so it renders its own markup instead of recursing — every other subclass
# still flips to NDS in the NDS bucket.
#
# Each including component must define:
#   - #nds_variant_class: the NDS subclass to exclude from the flip.
#   - #nds_delegate: builds the NDS variant with the component's own args.
module NDSBucketResolvable
  extend ActiveSupport::Concern

  included do
    def before_render
      super
      @render_as_nds = nds_bucket? && !is_a?(nds_variant_class)
    end
  end

  private

  def render_as_nds?
    @render_as_nds
  end

  # ViewComponent delegates #helpers to the current view context, where
  # nds_layout? is exposed as a controller helper_method. Guard for view
  # contexts without that helper (e.g. mailers). When the A/B bucket can't be
  # resolved because there is no auth context (background jobs, isolated
  # component renders — Devise::MissingWarden), default to the legacy bucket:
  # legacy is the conservative default and rendering must never crash.
  def nds_bucket?
    return false unless helpers.respond_to?(:nds_layout?)

    helpers.nds_layout?
  rescue Devise::MissingWarden
    false
  end
end
