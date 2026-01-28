# frozen_string_literal: true

module Test
  class SmsPreviewController < ApplicationController
    before_action :render_not_found_in_production

    def show
      redirect_to '/rails/mailers/sms_text_mailer'
    end

    private

    def render_not_found_in_production
      IdentityConfig.store.rails_mailer_previews_enabled
    end
  end
end
