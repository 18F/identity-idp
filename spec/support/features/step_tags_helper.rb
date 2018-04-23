module Features
  module StripTagsHelper
    def strip_tags(*args)
      ActionController::Base.helpers.strip_tags(*args)
    end
  end
end
