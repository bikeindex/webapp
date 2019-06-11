class Admin::UsersController < Admin::BaseController
  include SortableTable
  before_filter :find_user, only: [:edit, :update, :destroy]
  layout "new_admin"

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @users = matching_users.reorder("users.#{sort_column} #{sort_direction}").page(page).per(per_page)
    render layout: "new_admin"
  end

  def show
    redirect_to edit_admin_user_url
  end

  def edit
    # If the user has a bunch of bikes, it can cause timeouts. In those cases, use rough approximation
    if @user.rough_approx_bikes.count > 25
      bikes = @user.rough_approx_bikes
    else
      bikes = @user.bikes
    end
    @bikescount = @user.bikes.count
    @bikes = bikes.reorder(created_at: :desc).limit(10)
  end

  def update
    @user.name = params[:user][:name]
    @user.email = params[:user][:email]
    @user.superuser = params[:user][:superuser]
    @user.developer = params[:user][:developer] if current_user.developer?
    @user.banned = params[:user][:banned]
    @user.username = params[:user][:username]
    @user.can_send_many_stolen_notifications = params[:user][:can_send_many_stolen_notifications]
    if @user.save
      @user.confirm(@user.confirmation_token) if params[:user][:confirmed]
      redirect_to admin_users_url, notice: "User Updated"
    else
      bikes = @user.bikes
      @bikes = BikeDecorator.decorate_collection(bikes)
      render action: :edit
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_url, notice: "User Deleted."
  end

  protected

  def sortable_columns
    %w[created_at email]
  end

  def find_user
    @user = User.friendly_username_find(params[:id])
    raise ActiveRecord::RecordNotFound unless @user.present?
  end

  def matching_users
    @search_ambassadors = ActiveRecord::Type::Boolean.new.type_cast_from_database(params[:search_ambassadors])
    @search_superusers = ActiveRecord::Type::Boolean.new.type_cast_from_database(params[:search_superusers])
    if current_organization.present?
      users = current_organization.users
    else
      users = User
    end
    users = users.ambassadors if @search_ambassadors
    users = users.superusers if @search_superusers
    users = users.admin_text_search(params[:query]) if params[:query].present?
    users
  end
end
