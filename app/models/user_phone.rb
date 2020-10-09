class UserPhone < ApplicationRecord
  acts_as_paranoid

  belongs_to :user
  has_many :notifications, as: :notifiable, dependent: :destroy

  validates_presence_of :user_id
  validates :phone, presence: true, uniqueness: {scope: :user_id}

  before_validation :set_calculated_attributes

  scope :legacy, -> { where(confirmation_code: "legacy_migration") }
  scope :confirmed, -> { where.not(confirmed_at: nil) }
  scope :unconfirmed, -> { where(confirmed_at: nil) }
  scope :waiting_confirmation, -> { unconfirmed.where("updated_at > ?", confirmation_timeout).where.not(confirmation_code: "legacy_migration") }

  def self.confirmation_timeout
    Time.current - 1.hour
  end

  def self.find_confirmation_code(str)
    waiting_confirmation.where(confirmation_code: str.gsub(/\s/, "")).first
  end

  def self.add_phone_for_user_id(user_id, phone_number)
    phone = Phonifyer.phonify(phone_number)
    matching_phone = where(user_id: user_id, phone: phone).first
    if matching_phone.present?
      matching_phone.resend_confirmation_if_reasonable!
      return matching_phone
    end
    up = new(user_id: user_id, phone: phone)
    up.generate_confirmation
    up.send_confirmation_text
    up
  end

  def expired?
    unconfirmed? && updated_at < self.class.confirmation_timeout
  end

  # How phones pre-UserPhone model were migrated in
  def legacy?
    confirmation_code == "legacy_migration"
  end

  # Protect against overenthusiastic clicking
  def resend_confirmation?
    return true if legacy?
    unconfirmed? && updated_at < Time.current - 2.minutes
  end

  def resend_confirmation_if_reasonable!
    return false unless resend_confirmation?
    generate_confirmation
    send_confirmation_text
  end

  def confirmed?
    confirmed_at.present?
  end

  def unconfirmed?
    !confirmed?
  end

  def confirm!
    return true if confirmed?
    result = update(confirmed_at: Time.current)
    # Bump user to reset the general_alerts
    user.update(updated_at: Time.current, skip_update: false)
    result
  end

  def confirmation_display
    return nil unless confirmation_code.present?
    confirmation_code[0..2] + " " + confirmation_code[3..-1]
  end

  def confirmation_message
    "Bike Index confirmation code:  #{confirmation_display}"
  end

  def set_calculated_attributes
    self.phone = Phonifyer.phonify(phone)
    self.confirmation_code ||= new_confirmation
  end

  def send_confirmation_text
    UserPhoneConfirmationWorker.perform_async(id) unless confirmed?
  end

  def generate_confirmation
    update_attribute :confirmation_code, new_confirmation
  end

  private

  def new_confirmation
    (SecureRandom.random_number(9e6) + 1e6).to_i
  end
end
