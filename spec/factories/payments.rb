FactoryBot.define do
  factory :payment do
    user { FactoryBot.create(:user) }
    amount_cents { 999 }
    payment_method { "stripe" }
    first_payment_date { Time.current }
    factory :payment_check do
      payment_method { "check" }
    end
  end
end
