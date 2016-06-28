class FrontGearType < ActiveRecord::Base
  def self.old_attr_accessible
    %w(name count internal standard)
  end
  validates_presence_of :name, :count
  validates_uniqueness_of :name
  has_many :bikes

  scope :standard, -> { where(standard: true) }
  scope :internal, -> { where(internal: true) }

  def self.fixed
    where(name: '1', count: 1, internal: false, standard: true).first_or_create
  end

  before_create :set_slug
  def set_slug
    self.slug = Slugifyer.slugify(self.name)
  end
end
