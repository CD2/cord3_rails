Cord::Engine.routes.draw do
  get '/*api/schema', to: 'api_base#schema'
  get '/*api/ids', to: 'api_base#ids'
  get '/*api/fields', to: 'api_base#fields'
  post '/*api/perform/:action_name', to: 'api_base#perform'
  get '/*api', to: 'api_base#index'

  post '/', to: 'api_base#respond'
end
