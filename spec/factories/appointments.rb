FactoryBot.define do
  factory :appointment do
    organization { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["virtual_line"]) }
    location { FactoryBot.create(:location, organization: organization) }
    sequence(:email) { |n| "bike_owner#{n}@example.com" }
    sequence(:name) { |n| "some name #{n}" }
    reason { AppointmentConfiguration.default_reasons.first }
    # This is useful for controller specs that require that the organization have things enabled
    factory :appointment_with_virtual_line_on do
      location { FactoryBot.create(:location, :with_virtual_line_on) }
    end
  end
end
