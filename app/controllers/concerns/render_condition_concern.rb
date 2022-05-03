module RenderConditionConcern
  extend ActiveSupport::Concern

  module ClassMethods
    def check_or_render_not_found(callable, **kwargs)
      before_action(**kwargs) do
        next if callable.call
        respond_to do |format|
          format.html { render_not_found }
          format.json { render_json_not_found }
        end
      end
    end
  end
end
