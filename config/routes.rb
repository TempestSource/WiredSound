Rails.application.routes.draw do
  get 'login', to: 'sessions#new'

  namespace :api do
    namespace :v1 do
      namespace :auth do
        post "login", to: "auth#login"
        post "sign_up", to: "auth#sign_up"
      end
    end

    resources :songs, controller: "songs"
    resources :artists, controller: "artists"
    resources :hashes, controller: "hashes"
    resources :albums, controller: "albums"
    resources :releases, controller: "album_releases"
    resources :song_artists
    resources :album_artists
    resources :entries
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "songs#index"

  resource :settings, only: [:show, :update]

  resources :songs do
    member do
      get :link
      get :play
    end
  end
end