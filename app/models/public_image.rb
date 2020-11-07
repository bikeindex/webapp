class PublicImage < ApplicationRecord
  KIND_ENUM = {
    photo_uncategorized: 0,
    photo_stock: 3,
    photo_of_user_with_bike: 4, # property claim
    photo_of_serial: 5, # property claim
    photo_of_receipt: 6 # property claim
  }.freeze

  mount_uploader :image, ImageUploader # Not processed in background, because they are uploaded directly
  belongs_to :imageable, polymorphic: true

  default_scope { where(is_private: false).order(:listing_order) }
  scope :bikes, -> { where(imageable_type: "Bike") }

  before_save :set_calculated_attributes
  after_commit :enqueue_after_commit_jobs

  enum kind: KIND_ENUM

  def default_name
    if imageable_type == "Bike"
      self.name = "#{imageable&.title_string} #{imageable&.frame_colors&.to_sentence}"
    elsif image
      self.name ||= File.basename(image.filename, ".*").titleize
    end
  end

  def set_calculated_attributes
    self.kind ||= "photo_uncategorized"
    self.name = (name || default_name).truncate(100)
    return true if listing_order && listing_order > 0
    self.listing_order = imageable&.public_images&.length || 0
  end

  def enqueue_after_commit_jobs
    if external_image_url.present? && image.blank?
      return ExternalImageUrlStoreWorker.perform_async(id)
    end
    imageable&.update_attributes(updated_at: Time.current)
    return true unless imageable_type == "Bike"
    AfterBikeSaveWorker.perform_async(imageable_id)
  end
end
