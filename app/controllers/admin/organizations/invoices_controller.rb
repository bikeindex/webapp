class Admin::Organizations::InvoicesController < Admin::BaseController
  before_action :find_organization
  before_action :find_invoice, only: %i[edit update]
  before_action :find_paid_features, only: %i[new edit]

  def index
    @invoices = @organization.invoices.order(id: :desc)
  end

  def new
    @invoice ||= @organization.invoices.new
  end

  def show
    redirect_to edit_admin_organization_invoice_path
  end

  def edit; end

  def create
    @invoice = @organization.invoices.build(permitted_parameters.except(:paid_feature_ids))
    if @invoice.save
      # Invoice has to be created before it can get paid_feature_ids
      @invoice.paid_feature_ids = permitted_parameters[:paid_feature_ids]
      flash[:success] = "Invoice created"
      redirect_to admin_organization_invoices_path(organization_id: @organization.to_param)
    else
      render :new
    end
  end

  def update
    if @invoice.update_attributes(permitted_parameters)
      flash[:success] = "Invoice created"
      redirect_to admin_organization_invoices_path(organization_id: @organization.to_param)
    else
      render :edit
    end
  end

  protected

  def find_paid_features
    @paid_features = PaidFeature.order(:name)
  end

  def permitted_parameters
    params.require(:invoice).permit(:paid_feature_ids, :amount_due)
          .merge(subscription_start_at: TimeParser.parse(params.dig(:invoice, :subscription_start_at), params.dig(:invoice, :timezone)))
  end

  def find_organization
    @organization = Organization.friendly_find(params[:organization_id])
    unless @organization
      flash[:error] = "Sorry! That organization doesn't exist"
      redirect_to admin_organizations_url and return
    end
  end

  def find_invoice
    @invoice = @organization.invoices.find(params[:id])
  end
end
