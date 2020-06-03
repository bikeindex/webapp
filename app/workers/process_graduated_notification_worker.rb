class ProcessGraduatedNotificationWorker < ApplicationWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    1.hour
  end

  def perform(graduated_notification_id = nil)
    return enqueue_workers unless graduated_notification_id.present?

    graduated_notification = GraduatedNotification.not_marked_remaining.where(organization_id: org_id, bike_id: bike_id).first
    return graduated_notification if graduated_notification.present?

    graduated_notification = GraduatedNotification.create(organization_id: org_id, bike_id: bike_id)
    graduated_notification.process_notification!
    graduated_notification
  end

  def enqueue_workers
    organizations.each do |organization|
      GraduatedNotification.bike_ids_to_notify(organization).each do |bike_id|
        self.class.perform_async(organization.id, bike_id)
      end
    end
  end
end