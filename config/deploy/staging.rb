set :stage, :staging

set :user, 'bc-grunt'

server 'stage.bcon.io', user: fetch(:user), roles: %w{web app db}

set :deploy_to, "/var/www/stage/#{fetch(:application)}"

set :uploads_path, "#{fetch(:deploy_to)}/shared/web/app/uploads"

set :wp, "cd #{fetch(:deploy_to)}/current/vendor/wp-cli/wp-cli/bin ; /usr/bin/wp"

set :linked_files, %w{.env web/.htaccess}

fetch(:default_env).merge!(wp_env: :staging)