Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # storage(ActiveStorage 保存先)の書き込み可否まで確認する healthcheck。
  # /up は boot 確認のみのため、storage 破損(権限/マウント/RO/ディスクフル/I-O)を
  # 検知する用途で compose の platform healthcheck から叩く (issue#330)。
  get "health/storage" => "health#storage", as: :storage_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # LINE Webhook
  post "/webhook/line", to: "line_webhook#receive"

  # API
  namespace :api do
    namespace :v1 do
      resources :cleaning_manuals, only: [ :index, :show ] do
        collection do
          post :generate
        end
        member do
          get :status
        end
        resources :cleaning_sessions, only: [ :create ]
      end

      resources :cleaning_sessions, only: [ :show ] do
        member do
          get :current_step
          post :judge
          patch :skip
          patch :suspend
          patch :resume
          get :report
        end
      end

      resources :amex_statements, only: [] do
        collection do
          post :process_statement
        end
        member do
          get :status
        end
      end

      resources :bank_statements, only: [] do
        collection do
          post :process_statement
        end
        member do
          get :status
        end
      end

      resources :invoices, only: [] do
        collection do
          post :process_statement
        end
        member do
          get :status
        end
      end

      resources :receipts, only: [] do
        collection do
          post :process_receipt
        end
        member do
          get :status
        end
      end

      resources :journal_entries, only: [ :index, :show, :update ] do
        collection do
          get :export
        end
      end
    end
  end

  # Web UI
  resources :clients do
    resources :payment_cards, only: %i[create destroy]
  end
  resources :cleaning_manuals, only: [ :index, :show, :new ]
  resources :cleaning_sessions, only: [ :new, :show ] do
    member do
      get :report
    end
  end
  resources :amex_statements, only: [ :new ]
  resources :bank_statements, only: [ :new ]
  resources :invoices, only: [ :new ]
  resources :receipts, only: [ :new ]
  resources :statement_batches, only: [ :show, :destroy ]
  resources :journal_entries, only: [ :index, :show, :edit, :update, :destroy ] do
    collection do
      get :export
    end
  end

  root "clients#index"
end
