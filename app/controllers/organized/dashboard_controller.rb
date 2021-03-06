module Organized
  class DashboardController < Organized::BaseController
    before_action :set_fallback_period
    before_action :set_period, only: [:index]
    helper_method :bikes_for_graph

    def root
      if current_organization.ambassador?
        redirect_to organization_ambassador_dashboard_path
      else
        redirect_to organization_bikes_path
      end
    end

    def index
      # Only render this page if the organization has overview_dashboard (or it's a superuser)
      if !current_organization.overview_dashboard? && !current_user.superuser?
        redirect_to organization_bikes_path
        return
      end

      @child_organizations = current_organization.child_organizations
      @bikes_in_organizations = Bike.unscoped.current.organization(current_organization.nearby_and_partner_organization_ids).where(created_at: @time_range)
      @bikes_in_organization_count = current_organization.bikes.where(created_at: @time_range).count

      if current_organization.regional?
        @bikes_not_in_organizations = current_organization.nearby_bikes.where.not(id: @bikes_in_organizations.pluck(:id)).where(created_at: @time_range)

        @bikes_in_child_organizations_count = Bike.organization(@child_organizations.pluck(:id)).where(created_at: @time_range).count
        @bikes_in_nearby_organizations_count = Bike.organization(current_organization.regional_ids).where(created_at: @time_range).count
        @bikes_in_region_not_in_organizations_count = @bikes_not_in_organizations.count
      end
      if current_organization.enabled?("claimed_ownerships")
        non_org_ownerships = Ownership.unscoped.joins(:bike).where(bikes: {creation_organization_id: current_organization.id})
          .where.not(owner_email: current_organization.users.pluck(:email))
        # In general, we're not using Bike#creation_organization_id - mostly, it should be accessed through creation_state
        # but this requires creation_organization_id for ease of joining
        @claimed_ownerships = non_org_ownerships.where(claimed_at: @time_range)
        # We added this - but it isn't a relevant metric for most organizations.
        # It's only relevant to organizations that register to themselves first (e.g. Pro's Closet)
        @ownerships_to_new_owner = non_org_ownerships.where(created_at: @time_range)
      end
    end

    private

    def set_fallback_period
      @period = "year" unless params[:period].present?
    end
  end
end
