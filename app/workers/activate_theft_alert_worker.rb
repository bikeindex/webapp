class ActivateTheftAlertWorker < ApplicationWorker
  def perform(theft_alert_id, force_activate: false)
    theft_alert = TheftAlert.find(theft_alert_id)
    return false unless theft_alert.pending?
    unless force_activate
      return false unless theft_alert.activateable?
    end
    if theft_alert.activating_at.blank?
      new_data = theft_alert.facebook_data || {}
      theft_alert.update(facebook_data: new_data.merge(activating_at: Time.current.to_i))
    end
    Facebook::AdsIntegration.new.create_for(theft_alert)
    theft_alert.reload
    # If the post_url is blank, run create_for again to try to get the story id
    if theft_alert.facebook_post_url.blank?
      Facebook::AdsIntegration.new.create_for(theft_alert)
    end
    # And mark the theft alert active
    theft_alert.update(begin_at: theft_alert.calculated_begin_at,
                       end_at: theft_alert.calculated_end_at,
                       status: "active")
  end
end
