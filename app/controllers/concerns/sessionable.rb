module Sessionable
  extend ActiveSupport::Concern
  def skip_if_signed_in
    return nil unless current_user.present?
    unless return_to_if_present
      flash[:success] = "You're already signed in!"
      redirect_to user_home_url and return
    end
  end

  def sign_in_and_redirect(user)
    session[:last_seen] = Time.now
    if ActiveRecord::Type::Boolean.new.type_cast_from_database(params.dig(:session, :remember_me))
      cookies.permanent.signed[:auth] = cookie_options(user)
    else
      default_session_set(user)
    end
    remove_instance_variable(:@current_user) # remove current_user, so it can be re-memoized

    if params[:partner].present? || session[:partner].present? # Check present? of both in case one is empty
      session[:partner] = nil # Ensure they won't be redirected in the future
      redirect_to "https://new.bikehub.com/account" and return
    elsif user.unconfirmed?
      render_partner_or_default_signin_layout(redirect_path: please_confirm_email_users_path) and return
    elsif !return_to_if_present
      flash[:success] = "Logged in!"
      redirect_to user_root_url and return
    end
  end

  def default_session_set(user)
    cookies.signed[:auth] = cookie_options(user)
  end

  protected

  def cookie_options(user)
    c = {
      httponly: true,
      value: [user.id, user.auth_token]
    }
    # In development, secure: true breaks the cookie storage. Only add if production
    Rails.env.production? ? c.merge(secure: true) : c
  end
end
