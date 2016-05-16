class BikeCreatorAssociator
  def initialize(bikeParam = nil)
    @bikeParam = bikeParam
  end

  def create_ownership(bike)
    send_email = true
    send = @bikeParam.params[:bike][:send_email] 
    if send == false
      send_email = false
    elsif send.present? && send != true && send.to_s[/false/i]
      send_email = false
    end
    OwnershipCreator.new(bike: bike, creator: @bikeParam.creator, send_email: send_email).create_ownership
  end

  def create_components(bike)
    ComponentCreator.new(bike: bike, bikeParam: @bikeParam).create_components_from_params
  end

  def create_stolenRecord(bike)
    StolenRecordUpdator.new(bike: bike, user: @bikeParam.creator, bikeParam: @bikeParam.params).create_new_record
    StolenRecordUpdator.new(bike: bike).set_creation_organization if bike.creation_organization.present?
    bike.save
  end

  def create_normalized_serial_segments(bike)
    bike.create_normalized_serial_segments
  end

  def attach_photo(bike)
    return true unless @bikeParam.image.present?
    publicImage = PublicImage.new(image: @bikeParam.image)
    publicImage.imageable = bike
    publicImage.save
    @bikeParam.update_attributes(image_processed: true)
    bike.reload
  end
  
  def attach_photos(bike)
    return nil unless @bikeParam.params[:photos].present?
    photos = @bikeParam.params[:photos].uniq.take(7)
    photos.each { |p| PublicImage.create(imageable: bike, remote_image_url: p) }
  end

  def add_other_listings(bike)
    return nil unless @bikeParam.params[:bike][:other_listing_urls].present?
    urls = @bikeParam.params[:bike][:other_listing_urls]
    urls.each { |url| OtherListing.create(url: url, bike_id: bike.id) }
  end

  def associate(bike)
    begin 
      create_ownership(bike)
      create_components(bike)
      create_normalized_serial_segments(bike)
      create_stolenRecord(bike) if bike.stolen
      attach_photo(bike)
      attach_photos(bike)
      add_other_listings(bike)
      bike.reload
    rescue => e
      bike.errors.add(:association_error, e.message)
    end
    bike
  end

end