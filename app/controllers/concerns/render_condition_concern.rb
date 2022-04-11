module RenderConditionConcern
  extend ActiveSupport::Concern

  module ClassMethods
    def render_if(callable, **kwargs)
      before_action(**kwargs) { render_not_found if !callable.call }
    end
  end
end
