# frozen_string_literal: true

module StringManagerConcern
  def manage_strings
    StringManager.instance.reset_tracking
  end
end
