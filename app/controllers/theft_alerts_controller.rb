class TheftAlertsController < ApplicationController
  before_action :ensure_user_allowed_to_create_theft_alert

  def create
    theft_alert_plan = TheftAlertPlan.find(params[:theft_alert_plan_id])
    theft_alert = TheftAlert.create!(
      stolen_record: @bike.current_stolen_record,
      theft_alert_plan: theft_alert_plan,
      creator: current_user,
    )

    payment = TheftAlertPaymentCreator.create!(
      user: current_user,
      stripe_email: params[:stripe_email],
      stripe_token: params[:stripe_token],
      stripe_amount: params[:stripe_amount],
    )

    theft_alert.update(payment: payment)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    Honeybadger.notify(e)
    flash[:error] = "We were unable to process your order. Please contact support."
  rescue Stripe::StripeError => e
    Honeybadger.notify(e)
    flash[:error] = "Your order is pending, but we were unable to complete payment. Please contact support."
  else
    flash[:success] = "Success! Your order is pending."
  ensure
    redirect_to edit_bike_url(@bike, params: { page: :alert })
  end

  private

  def ensure_user_allowed_to_create_theft_alert
    @bike = Bike.find_by(id: params[:bike_id])
    @current_ownership = @bike&.current_ownership
    return true if @bike&.authorize_for_user!(current_user)

    flash[:error] = "You don't have permission to do that. Please contact support."
    redirect_to bikes_url and return
  end
end
