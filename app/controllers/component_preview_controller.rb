# frozen_string_literal: true

class ComponentPreviewController < ViewComponentsController
  if IdentityConfig.store.component_previews_enabled
    include ActionView::Helpers::AssetTagHelper
    helper Lookbook::PreviewHelper
    include ScriptHelper
    include StylesheetHelper

    helper_method :enqueue_component_scripts
    alias_method :enqueue_component_scripts, :javascript_packs_tag_once

    helper_method :enqueue_component_stylesheets
    alias_method :enqueue_component_stylesheets, :stylesheet_tag_once

    helper_method :nds_layout?

    before_action :set_locale

    def set_locale
      I18n.locale = LocaleChooser.new(params[:locale], request).locale
    end

    # Force the NDS bucket in previews via ?ui_test_bucket=nds so
    # bucket-conditional components can be inspected in both looks. Previews
    # have no A/B or auth context (the app's full resolution also reads a
    # cookie and the A/B assignment), so this honors only the query param and
    # defaults to the legacy bucket.
    def nds_layout?
      params[:ui_test_bucket] == 'nds'
    end
  end
end
