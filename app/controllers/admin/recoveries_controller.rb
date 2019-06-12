class Admin::RecoveriesController < Admin::BaseController
  layout "new_admin"

  def index
    unless params[:search_recovery_dispay_status]
      if params[:all_recoveries]
        recoveries = StolenRecord.recovered.includes(:bike).order("date_recovered desc")
      elsif params[:displayed]
        recoveries = StolenRecord.recovered.displayed.includes(:bike).order("date_recovered desc")
      elsif params[:not_displayed]
        recoveries = StolenRecord.recovered.not_displayed.includes(:bike).order("date_recovered desc")
      elsif params[:eligible_no_photo]
        recoveries = StolenRecord.recovered.displayable_no_photo.includes(:bike).order("date_recovered desc")
      elsif params[:not_eligible]
        recoveries = StolenRecord.recovered.not_eligible.includes(:bike).order("date_recovered desc")
      else
        recoveries = StolenRecord.recovered.waiting_on_decision.includes(:bike).order("date_recovered desc")
      end
    end
    @recoveries_count = recoveries.count
    @waiting = StolenRecord.recovered.waiting_on_decision.count + StolenRecord.recovered.displayable_no_photo.count
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @recoveries = recoveries.page(page).per(per_page)
  end

  def show
    redirect_to edit_admin_recovery_url
  end

  def edit
    @recovery = StolenRecord.unscoped.find(params[:id])
    @bike = @recovery.bike.decorate
  end

  def update
    @stolen_record = StolenRecord.unscoped.find(params[:id])
    if params[:is_not_displayable].present?
      @stolen_record.recovery_display_status = "not_displayed"
    elsif params[:mark_as_eligible].present?
      @stolen_record.recovery_display_status = "waiting_on_decision"
    end
    if @stolen_record.update_attributes(permitted_parameters)
      flash[:success] = "Recovery Saved!"
      redirect_to admin_recoveries_url
    else
      raise StandardError
      render action: :edit
    end
  end

  def approve
    if params[:multipost]
      enqueued = false
      if params[:recovery_selected].present?
        params[:recovery_selected].keys.each do |rid|
          recovery = StolenRecord.unscoped.find(rid)
          unless recovery.recovery_posted && recovery.can_share_recovery == false
            RecoveryNotifyWorker.perform_async(rid.to_i)
            enqueued = true
          end
        end
      end
      if enqueued
        flash[:success] = "Recovery notifications enqueued. Recoveries marked 'can share' haven't been posted, because they need your loving caress."
      else
        flash[:error] = "No recoveries were selected (or only recoveries you need to caress were)"
      end
      redirect_to admin_recoveries_url
    else
      RecoveryNotifyWorker.perform_async(params[:id].to_i)
      flash[:success] = "Recovery notification enqueued."
      redirect_to admin_recoveries_url
    end
  end

  private

  def permitted_parameters
    params.require(:stolen_record).permit(StolenRecord.old_attr_accessible)
  end
end
