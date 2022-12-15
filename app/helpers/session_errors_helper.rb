module SessionErrorsHelper
  def timeout
    distance_of_time_in_words(
      @expires_at,
      Time.zone.now,
      except: :seconds,
    )
  end
end
