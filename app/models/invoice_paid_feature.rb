# frozen_string_literal: true

class InvoiceOrganizationFeature < ActiveRecord::Base
  belongs_to :invoice
  belongs_to :paid_feature
end
