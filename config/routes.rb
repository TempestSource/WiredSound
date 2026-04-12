Rails.application.routes.draw do
  resources :artist_infos, only: [:index, :show]
  resources :album_releases, only: [:index, :show]
  resources :album_artists, only: [:index, :show]
  resources :album_infos, only: [:index, :show]
  resources :hash_matches, only: [:index, :show]
  resources :song_artists, only: [:index, :show]
  resources :song_infos, only: [:index, :show]
  resources :songs do
    member do
      get :play # This creates the URL /songs/:id/play
    end
  end
  get 'login', to: 'sessions#new'
  namespace :api do
    get "posts/index"
    get "posts/show"
    get "posts/create"
    get "posts/update"
    get "posts/destroy"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  get "up" => "rails/health#show", as: :rails_health_check

  # Your UI routes
  root "songs#index"

  resource :settings, only: [:show, :update]

  resources :songs do
    member do
      get :link
    end
  end
end