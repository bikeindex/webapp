# Warning: BikeCreator forces every bike to have an ownership
# ... But this factory allows creating bikes without ownerships
FactoryGirl.define do
  factory :bike do
    # transient do # will be transient once we drop the deprecated creation attributes
      creator { FactoryGirl.create(:user) }
    # end
    serial_number
    manufacturer { FactoryGirl.create(:manufacturer) }
    sequence(:owner_email) { |n| "bike_owner#{n}@example.com" }
    creation_state { FactoryGirl.create(:creation_state, creator: creator) }
    primary_frame_color { Color.black }
    cycle_type { CycleType.bike }
    propulsion_type { PropulsionType.foot_pedal }

    factory :creation_organization_bike do
      transient do
        organization { FactoryGirl.create(:organization) }
      end
      creation_state { FactoryGirl.create(:creation_state, creator: creator, organization: organization) }
    end

    factory :stolen_bike do
      transient do
        latitude { 40.7143528 }
        longitude { -74.0059731 }
      end
      stolen true
      after(:create) do |bike, evaluator|
        create(:stolen_record,
               bike: bike,
               latitude: evaluator.latitude,
               longitude: evaluator.longitude)
        bike.save # updates current_stolen_record
        bike.reload
      end
      factory :recovered_bike do
        recovered true
      end
    end
  end
end
