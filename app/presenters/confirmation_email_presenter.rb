class ConfirmationEmailPresenter
  def initialize(user, view)
    @user = user
    @view = view
  end

  def first_sentence # rubocop:disable MethodLength
    if user.reset_requested_at.present?
      I18n.t('mailer.confirmation_instructions.first_sentence.reset_requested', app: app_link)
    elsif user.confirmed_at.present?
      I18n.t(
        'mailer.confirmation_instructions.first_sentence.confirmed',
        app: app_link, confirmation_period: confirmation_period
      )
    else
      I18n.t(
        'mailer.confirmation_instructions.first_sentence.unconfirmed',
        app: app_link, confirmation_period: confirmation_period
      )
    end
  end

  def app_link
    view.link_to(APP_NAME, view.root_url, class: 'gray')
  end

  def confirmation_period
    current_time = Time.zone.now

    view.distance_of_time_in_words(
      current_time, current_time + Devise.confirm_within, true, accumulate_on: :hours
    )
  end

  private

  attr_reader :user, :view
end
