Rails.application.routes.draw do
  get "health", to: "health#show"
  resources :items, only: [:index, :show, :create, :destroy]
end
