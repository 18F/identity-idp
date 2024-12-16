# frozen_string_literal: true

module StringManagerConcern
  def reset_strings_manager
    StringManager.instance.reset_tracking
  end
end
