class UserAlert < ApplicationRecord
  KIND_ENUM = {
    phone_waiting_confirmation: 0,
    theft_alert_without_photo: 1,
    stolen_bikes_without_locations: 2,
    unassigned_bike_org: 3
  }.freeze

  belongs_to :bike
  belongs_to :user
  belongs_to :user_phone
  belongs_to :theft_alert
  belongs_to :organization

  validates :user_phone_id, uniqueness: {scope: [:kind, :user_id]}, allow_blank: true
  validates :theft_alert_id, uniqueness: {scope: [:kind, :user_id]}, allow_blank: true
  # Probably not unique unless checking all references
  # validates :bike_id, uniqueness: {scope: [:kind, :user_id]}, allow_blank: true
  # validates :organization_id, uniqueness: {scope: [:kind, :user_id]}, allow_blank: true

  enum kind: KIND_ENUM

  before_validation :set_calculated_attributes

  scope :dismissed, -> { where.not(dismissed_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }
  scope :inactive, -> { where.not(resolved_at: nil).or(where(dismissed_at: nil)) }
  scope :active, -> { where(resolved_at: nil, dismissed_at: nil) }

  def self.find_or_build_by(attrs)
    where(attrs).first || new(attrs)
  end

  def self.theft_alert_without_photo(user:, theft_alert:)
    user_alert = UserAlert.find_or_build_by(kind: "theft_alert_without_photo",
      user_id: user.id, theft_alert_id: theft_alert_id.id)
    if theft_alert.missing_photo?
      user_alert.bike_id = theft_alert.bike_id
      user_alert.save
    else
      # Don't create if theft alert already has a photo
      user_alert.id.blank? ? true : user_alert.resolve!
    end
  end

  def self.update_phone_waiting_confirmation(user:, user_phone:)
    user_alert = UserAlert.find_or_build_by(kind: "phone_waiting_confirmation",
      user_id: user.id, user_phone_id: user_phone.id)
    if user_phone.confirmed?
      # Don't create if phone is already confirmed
      user_alert.id.blank? ? true : user_alert.resolve!
    else
      user_alert.save unless user_phone.legacy?
    end
  end

  def dismissed?
    dismissed_at.present?
  end

  def resolved?
    resolved_at.present?
  end

  def inactive?
    dismissed? || resolved?
  end

  def active?
    !inactive?
  end

  def dismiss!
    return true if dismissed?
    update(dismissed_at: Time.current)
  end

  def resolve!
    return true if resolved?
    update(resolved_at: Time.current)
  end

  def set_calculated_attributes
  end
end
