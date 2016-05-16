class Admin::UsersController < Admin::BaseController
  before_filter :find_user, only: [:show, :edit, :update, :destroy]

  def index
    if params[:user_query]
      # if params[:email]
      users = User.admin_text_search(params[:user_query])
      # users = User.where('email LIKE ?', params[:user_query]).all
      # users += User.where('name LIKE ?', params[:user_query]).all
      # @users = users
    elsif params[:superusers]
      users = User.where(superuser: true)
    elsif params[:content_admins]
      users = User.where(is_content_admin: true)
    else 
      users = User.order("created_at desc")
    end
    page = params[:page] || 1
    perPage = params[:perPage] || 25
    @users = users.page(page).per(perPage)
  end

  def edit
    bikes = @user.bikes
    @bikes = BikeDecorator.decorate_collection(bikes)
  end

  def update
    @user.name = params[:user][:name]
    @user.email = params[:user][:email]
    @user.confirmed = params[:user][:confirmed]
    @user.superuser = params[:user][:superuser]
    @user.developer = params[:user][:developer] if current_user.developer
    @user.is_content_admin = params[:user][:is_content_admin]
    @user.banned = params[:user][:banned]
    @user.username = params[:user][:username]
    @user.can_send_many_stolenNotifications = params[:user][:can_send_many_stolenNotifications]
    if @user.save
      redirect_to admin_users_url, notice: 'User Updated'
    else
      bikes = @user.bikes
      @bikes = BikeDecorator.decorate_collection(bikes)
      render action: :edit
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_url, notice: 'User Deleted.'
  end
  

  protected

  def find_user
    @user = User.find_by_username(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless @user.present?
  end

end
