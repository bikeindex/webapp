module Organized
  class ParkingNotificationsController < Organized::BaseController
    before_action :ensure_access_to_parking_notifications!, only: %i[index create]
    before_action :set_period, only: [:index]
    skip_before_action :set_x_frame_options_header, only: [:email]

    def index
      @page_data = {
        google_maps_key: ENV["GOOGLE_MAPS"],
        map_center_lat: current_organization.map_focus_coordinates[:latitude],
        map_center_lng: current_organization.map_focus_coordinates[:longitude],
      }

      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)

      respond_to do |format|
        format.html
        format.json do
          page = params[:page] || 1
          per_page = params[:per_page] || 100
          # TODO: add sortable here
          records = matching_parking_notifications.reorder(created_at: :desc).includes(:user, :bike, :impound_record)
          render json: records.page(page).per(per_page),
                 root: "parking_notifications",
                 each_serializer: ParkingNotificationSerializer
        end
      end
    end

    def show
      @parking_notification = parking_notifications.find(params[:id])
      @related_notifications = @parking_notification.associated_notifications.reorder(id: :desc)
      @bike = @parking_notification.bike
    end

    def email
      @organization = current_organization
      @email_preview = true
      @parking_notification = parking_notifications.find(params[:id])
      @bike = @parking_notification.bike
      @retrieval_link_url = @parking_notification.retrieval_link_token.present? ? "#" : nil
      render template: "/organized_mailer/parking_notification", layout: "email"
    end

    def create
      if params[:kind].present? # It's a send_additional kind
        create_and_send_repeats(params[:kind], params[:ids].as_json)
      else
        @parking_notification = ParkingNotification.new(permitted_parameters)
        if @parking_notification.save
          flash[:success] = translation(:successfully_created, bike_type: @parking_notification.bike.type)
        else
          flash[:error] = translation(:unable_to_create, errors: @parking_notification.errors.full_messages.to_sentence)
        end
      end
      # pp "repeated: #{@notifications_repeated.pluck(:id)}, failed: #{@notifications_failed_resolved.pluck(:id)}"
      if @redirect_location.present?
        redirect_to @redirect_location
      else
        redirect_back(fallback_location: organization_parking_notifications_path(organization_id: current_organization.to_param))
      end
    end

    helper_method :matching_parking_notifications, :search_params_present?

    private

    def parking_notifications
      current_organization.parking_notifications
    end

    def matching_parking_notifications
      return @matching_parking_notifications if defined?(@matching_parking_notifications)
      notifications = parking_notifications
      if params[:search_bike_id].present?
        notifications = notifications.where(bike_id: params[:search_bike_id])
      end
      if bike_search_params_present?
        notifications = notifications.where(bike_id: search_organization_bikes.pluck(:id))
      end
      @matching_parking_notifications = notifications.where(created_at: @time_range)
    end

    def search_params_present?
      # Eventually, will check period select, etc
      (params.keys & %w[search_bike_id]).any?
    end

    def permitted_parameters
      use_entered_address = ParamsNormalizer.boolean(params.dig(:parking_notification, :use_entered_address))
      params.require(:parking_notification)
            .permit(:message, :internal_notes, :bike_id, :kind, :is_repeat, :latitude, :longitude, :accuracy,
                    :street, :city, :zipcode, :state_id, :country_id)
            .merge(user_id: current_user.id, organization_id: current_organization.id, use_entered_address: use_entered_address)
    end

    def create_and_send_repeats(kind, ids)
      pp "#{ids.is_a?(Hash)}, #{ids.keys}"
      ids_array = case ids
      when ids.is_a?(Array) then ids
      when ids.is_a?(Hash) then ids.keys # parameters submitted look like this ids: { "12" => "12" }
      else
        ids.split(",")
      end.map { |id| id.strip.to_i }.reject(&:blank?)
      pp ids_array

      selected_notifications = parking_notifications.where(id: ids_array)
      # pp "ids_array #{ids_array} - #{selected_notifications.pluck(:id)} - #{selected_notifications.resolved.pluck(:id)}"
      # We can't update already resolved notifications - so add them to an ivar for displaying
      @notifications_failed_resolved = selected_notifications.resolved.includes(:user, :bike, :impound_record)
      successes = []
      ids_repeated = []

      selected_notifications.active.each do |parking_notification|
        target_notification = parking_notification.current_associated_notification
        # pp "o: #{parking_notification.id} - target: #{target_notification.id}, #{ids_repeated}"
        next if ids_repeated.include?(target_notification.id)
        ids_repeated << target_notification.id
        new_notification = target_notification.retrieve_or_repeat_notification!(kind: kind, user_id: current_user.id)
        successes << new_notification.id
      end
      @repeated_kind = kind
      @notifications_repeated = ParkingNotification.where(id: ids_repeated).includes(:user, :bike, :impound_record)
      # If sending only one repeat notification, redirect to that notification
      if ids_array.count == 1 && successes.count == 1
        @redirect_location = organization_parking_notification_path(successes.first, organization_id: current_organization.to_param)
      end
      # I don't think there will be a failure without error, retrieve_or_repeat_notification! should throw an error
      # rescuing makes it difficult to diagnose the problem, so we're just going to silently fail. sry
      # flash[:error] = "Unable to send notifications for #{(ids - successes).map { |i| "##{i}" }.join(", ")}"
    end

    def ensure_access_to_parking_notifications!
      return true if current_organization.enabled?("parking_notifications")
      flash[:error] = translation(:your_org_does_not_have_access)
      redirect_to organization_bikes_path(organization_id: current_organization.to_param)
      return
    end

    def bike_search_params_present?
      @interpreted_params.except(:stolenness).values.any? || @selected_query_items_options.any? || params[:email].present?
    end

    def search_organization_bikes
      bikes = current_organization.parking_notification_bikes
      bikes = bikes.search(@interpreted_params)
      bikes = bikes.organized_email_search(params[:email]) if params[:email].present?
      bikes
    end
  end
end
