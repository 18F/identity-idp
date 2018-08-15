module UserEagerLoading
  extend ActiveSupport::Concern

  module ClassMethods
    def load_current_user(with: [], only: nil)
      if only
        load_current_user_only_sometimes(with, only.map(&:to_s))
      else
        load_current_user_always(with)
      end
    end

    private

    def load_current_user_only_sometimes(with, only)
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def current_user
          @current_user ||= begin
            record = super
            if #{only.inspect}.include?(action_name)
              record && User.includes(#{with.inspect}).find(record.id)
            else
              record
            end
          end
        end
      METHOD
    end

    def load_current_user_always(with)
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def current_user
          @current_user ||= super && User.includes(#{with.inspect}).find(@current_user.id)
        end
      METHOD
    end
  end
end
