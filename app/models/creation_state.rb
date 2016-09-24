class CreationState < ActiveRecord::Base
  belongs_to :bike
  belongs_to :organization
  belongs_to :creator, class_name: 'User'

  def self.origins
    %w(embed embed_extended embed_partial api_v1 api_v2).freeze
  end

  before_validation :ensure_permitted_origin
  def ensure_permitted_origin
    self.origin = nil unless self.class.origins.include?(origin)
    true
  end

  after_create :create_bike_organization
  def create_bike_organization
    return true unless organization.present?
    BikeOrganization.where(bike_id: bike_id, organization_id: organization_id).first_or_create
  end
end
