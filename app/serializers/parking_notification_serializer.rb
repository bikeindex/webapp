class ParkingNotificationSerializer < ApplicationSerializer
  attributes :id,
             :kind,
             :kind_humanized,
             :status,
             :created_at,
             :lat,
             :lng,
             :user_id,
             :user_display_name,
             :bike,
             :notification_number,
             :impound_record_id,
             :unregistered_bike,
             :retrieved_at,
             :impound_record_at

  def created_at
    object.created_at.to_i
  end

  def user_id
    object.user_id
  end

  def user_display_name
    object.user&.display_name
  end

  def lat
    object.latitude
  end

  def lng
    object.longitude
  end

  def retrieved_at
    object.retrieved_at&.to_i
  end

  def impound_record_at
    object.impound_record&.created_at&.to_i
  end

  def bike
    bike_obj = object.bike
    {
      id: bike_obj&.id,
      title: bike_obj&.title_string,
    }
  end
end
