Rails.application.routes.draw do
  get 'login', to: 'sessions#new'
  get 'signup', to: 'registrations#new'
  namespace :api do
    get "api/index"
    get "api/show"
    get "api/create"
    get "api/update"
    get "api/destroy"

    resources :songs
    resources :artists
    resources :hashes
    resources :albums
    resources :entries

    resources :song_artists, only: [:index, :show]
    resources :releases, controller: "album_releases", only: [:index, :show]

    namespace :v1 do
      namespace :auth do
        post "login", to: "auth#login"
        post "sign_up", to: "auth#sign_up"
      end
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  get "up" => "rails/health#show", as: :rails_health_check

  # Your UI routes
  root "songs#index"

  resource :settings, only: [:show, :update]

  resources :songs do
    member do
      get :link
      get :play
    end
  end
end