class Admin::RecoveriesController < Admin::BaseController
  def index
    if params[:posted]
      @posted = true
      recoveries = StolenRecord.recovery_unposted.includes(:bike).order("date_recovered desc")
    elsif params[:all_recoveries]
      recoveries = StolenRecord.recovered.includes(:bike).order("date_recovered desc")
    else 
      recoveries = StolenRecord.displayable.includes(:bike).order("date_recovered desc")
    end
    page = params[:page] || 1
    perPage = params[:perPage] || 50
    @recoveries = recoveries.page(page).per(perPage)
  end

  def show
    redirect_to edit_admin_recovery_url
  end

  def edit
    @recovery = StolenRecord.unscoped.find(params[:id])
    @bike = @recovery.bike.decorate
  end

  def update
    @stolenRecord = StolenRecord.unscoped.find(params[:id])
    if @stolenRecord.update_attributes(params[:stolenRecord])
      flash[:notice] = "Recovery Saved!"
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
            RecoveryNotifyWorker.perform_asynchronous(rid.to_i)
            enqueued = true
          end
        end
      end
      if enqueued
        flash[:notice] = "Recovery notifications enqueued. Recoveries marked 'can share' haven't been posted, because they need your loving caress."
      else 
        flash[:error] = "No recoveries were selected (or only recoveries you need to caress were)"
      end
      redirect_to admin_recoveries_url
    else
      RecoveryNotifyWorker.perform_asynchronous(params[:id].to_i)
      redirect_to admin_recoveries_url, notice: 'Recovery notification enqueued.'
    end
  end

end
