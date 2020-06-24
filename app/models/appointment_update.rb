class AppointmentUpdate < ApplicationRecord
  STATUS_ENUM = {
    waiting: 0,
    on_deck: 1,
    being_helped: 2,
    finished: 3,
    failed_to_find: 4,
    removed: 5,
    abandoned: 6,
    organization_reordered: 7
  }.freeze

  belongs_to :appointment
  belongs_to :user

  validates_presence_of :appointment_id

  enum status: STATUS_ENUM
  enum creator_type: Appointment::CREATOR_TYPE_ENUM

  after_commit :update_appointment_queue, on: [:create]

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def update_appointment_queue
    UpdateAppointmentOrder.perform_async(id)
  end
end
