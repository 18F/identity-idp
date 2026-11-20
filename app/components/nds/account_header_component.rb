# frozen_string_literal: true

module NDS
  # Net-new NDS signed-in header (renders only in the NDS layout): the gov banner plus an
  # .account-header with the logo, the email menu (sign out) and, below the tablet
  # breakpoint, the mobile menu with the account navigation. Used by the NDS account
  # shell layout, and by nds/application when a page sets content_for(:nds_account_header).
  class AccountHeaderComponent < BaseComponent
    attr_reader :user, :current

    def initialize(user:, current: nil)
      @user = user
      @current = current
    end

    def email
      user.last_sign_in_email_address&.email
    end
  end
end
