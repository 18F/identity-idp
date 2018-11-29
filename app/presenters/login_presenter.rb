class LoginPresenter
  include ActionView::Helpers::DateHelper

  def initialize(user:)
    @user = user
  end

  def current_sign_in_location_and_ip
    I18n.t('account.index.sign_in_location_and_ip', location: current_location, ip: current_ip)
  end

  def last_sign_in_location_and_ip
    I18n.t('account.index.sign_in_location_and_ip', location: last_location, ip: last_ip)
  end

  def current_timestamp
    timestamp = user.current_sign_in_at || Time.zone.now
    I18n.t(
      'account.index.sign_in_timestamp',
      timestamp: time_ago_in_words(
        timestamp, highest_measures: 2, two_words_connector: two_words_connector
      )
    )
  end

  def last_timestamp
    timestamp = user.last_sign_in_at || Time.zone.now
    I18n.t(
      'account.index.sign_in_timestamp',
      timestamp: time_ago_in_words(
        timestamp, highest_measures: 2, two_words_connector: two_words_connector
      )
    )
  end

  private

  attr_reader :user

  def current_location
    IpGeocoder.new(current_ip).location
  end

  def last_location
    IpGeocoder.new(last_ip).location
  end

  def current_ip
    user.current_sign_in_ip
  end

  def last_ip
    user.last_sign_in_ip
  end

  def two_words_connector
    " #{I18n.t('datetime.dotiw.two_words_connector')} "
  end
end
