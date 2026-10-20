Rails.application.routes.draw do
  root "dashboard#show"
  # The Today view and its pieces (re-rendered one at a time as Turbo Frames: ?part=hero).
  resource :today, only: :show, controller: "today"
  # The Calendar view (mode + date re-rendered as the "calendar" Turbo Frame) and its sheets.
  resource :calendar, only: :show, controller: "calendar"
  resources :events, only: %i[index show update] do
    get :directions, on: :member  # a QR code for the location (plan: second gap review)
  end
  # The Chores view ("chores" Turbo Frame, ?routine= to look at another routine) and completions.
  resource :chores, only: :show, controller: "chores"
  resources :chores, only: [] do
    resources :completions, only: %i[new create], controller: "chore_completions"
  end
  resources :chore_completions, only: :destroy
  # The Shopping view ("shopping" + "shopping-side" Turbo Frames; ?store= and ?drawer=1 are its state).
  resource :shopping, only: :show, controller: "shopping"
  resources :grocery_items, only: %i[create edit update destroy] do
    member do
      patch :check
      delete :check, action: :uncheck
    end
  end
  resource :cleared_groceries, only: %i[create destroy]
  # Photos: favourites.
  # To-dos (plan: People view): added and ticked off from the frame or a phone.
  resources :todos, only: %i[create destroy] do
    member do
      patch :complete
      patch :undo
    end
  end
  # The People view (plan: People view): the avatars, or one person's page.
  resource :people, only: :show, controller: "people"
  resources :photos, only: :update do
    get :image, on: :member  # an Immich photo's image, through us (plan: milestone 7)
  end
  # Home control: the view, device patches, sheets, scenes, climate, media, cameras.
  resource :control, only: :show, controller: "control"
  resources :devices, only: %i[index update] do
    get :garage, on: :member
  end
  resource :lights, only: :destroy   # "Turn everything off"
  resource :locks, only: :create     # "Lock all doors"
  resources :scene_activations, only: %i[create destroy]
  resource :thermostat, only: :update
  resource :media_player, only: :update
  resources :cameras, only: :show do
    get :snapshot, on: :member  # through the hub, for mapped cameras (plan: milestone 6)
  end
  # Alerts from the house (plan: milestone 6): Home Assistant automations call the hook; the frame acknowledges.
  post "hooks/home_assistant", to: "hooks#home_assistant", as: :hooks_home_assistant
  resource :water_valve, only: [] do
    post :close  # the leak takeover's "hold to shut off water"
  end
  resources :home_alerts, only: [] do
    patch :acknowledge, on: :member
  end
  # Live sync: a screen fetches the pieces a broadcast named, rendered for itself.
  resource :pieces, only: :show, controller: "pieces"
  # The demo drawer's server-side presets (time of day, calendar data mode), per browser session.
  resource :demo, only: :update, controller: "demo"

  resource :session, only: %i[new create destroy] do
    get  :verify
    post :confirm
  end

  resources :screens

  # Settings (plan: milestone 3): the household and everything it configures. Adults only.
  resource :settings, only: %i[show update], controller: "settings"
  namespace :settings do
    %i[people routines chores categories catalog_items todos].each do |area|
      resources area, except: :show do
        patch :move, on: :member
      end
    end
    # Photos (plan: milestone 7): sync Immich now, or clear the demo photos.
    resource :photos, only: :destroy do
      post :sync
    end
    # What happened (plan: milestone 5): the audit log.
    resource :activity, only: :show, controller: "activity"
    # The home (plan: milestone 5): rooms, devices and the rest mapped to the hub's entities.
    resource :home, only: %i[show destroy], controller: "home" do
      post :import
    end
    %i[rooms devices scenes cameras].each do |area|
      resources area, except: :show do
        patch :move, on: :member
      end
    end
    resource :climate, only: %i[edit update], controller: "climate"
    resource :media_player, only: %i[edit update]
    # Calendar feeds: synced on a schedule, or now.
    resources :calendar_sources, except: :show do
      post :sync, on: :member
    end
    # A store's page is its aisle order; categories move up and down it.
    resources :stores do
      patch :move, on: :member
      resources :aisles, only: [] do
        patch :move, on: :member
      end
    end
  end
  get "screens/enroll/:token", to: "screen_enrollments#create", as: :enroll_screen

  # Offline mode: the service worker caches the shell and the last page; the manifest installs it.
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  get "up" => "rails/health#show", as: :rails_health_check
end
