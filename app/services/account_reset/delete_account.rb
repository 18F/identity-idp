module AccountReset
  class DeleteAccount
    include ActiveModel::Model
    include GrantedTokenValidator

    def initialize(token)
      @token = token
    end

    def call
      @success = valid?

      if success
        notify_user_via_email_of_deletion
        destroy_user
      end

      FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_reader :success

    def destroy_user
      user.destroy!
    end

    def notify_user_via_email_of_deletion
      UserMailer.account_reset_complete(user.email_address.email).deliver_later
    end

    def extra_analytics_attributes
      {
        user_id: user.uuid,
        event: 'delete',
        email: user.email_address.email,
      }
    end
  end
end
