# frozen_string_literal: true

class DuplicateProfileConfirmation < ApplicationRecord
  belongs_to :profile

  def mark_some_accounts_not_recognized
    update!(confirmed_all: false)
  end

  def mark_all_accounts_recognized
    update!(confirmed_all: true)
  end
end
