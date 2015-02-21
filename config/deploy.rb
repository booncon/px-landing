set :application, 'px-landing'
set :repo_url, 'git@github.com:booncon/px-landing.git'

# Hardcodes branch to always be master
# This could be overridden in a stage config file
set :branch, :master

set :deploy_to, "/var/www/#{fetch(:application)}"

set :log_level, :info

set :linked_dirs, %w{web/app/uploads}

set :stage_script, "/var/www/stage/home/current/web/scripts"

# desc 'Symlink linked files'
#   task :linked_files do
#     next unless any? :linked_files
#     on release_roles :all do
#       execute :mkdir, '-p', linked_file_dirs(release_path)

#       fetch(:linked_files).each do |file|
#         target = release_path.join(file)
#         source = shared_path.join(file)
#         unless test "[ -L #{target} ]"
#           if test "[ -f #{target} ]"
#             execute :rm, target
#           end
#           execute :ln, '-s', source, target
#         end
#       end
#     end
#   end

# namespace :htpasswd do
#   desc "Pull the remote uploaded files"
#   task :link do
#     on roles(:all) do |host|
#       info "Linking the .htpasswd"
#       # puts "Fetching the uploads from #{fetch(:stage)}"
#       # system("rsync -avzh #{fetch(:user)}@#{host}:#{fetch(:uploads_path)} #{File.expand_path File.dirname(__FILE__)}/../web/app/")
#     end
#   end
# end

# after 'deploy:publishing', 'deploy:restart'

namespace :uploads do
  desc "Pull the remote uploaded files"
  task :pull do
    on roles(:all) do |host|
      puts "Fetching the uploads from #{fetch(:stage)}"
      system("rsync -avzh #{fetch(:user)}@#{host}:#{fetch(:uploads_path)} #{File.expand_path File.dirname(__FILE__)}/../web/app/")
    end
  end
end

namespace :db do
  desc "Pull the remote database"
  task :pull do
    on roles(:web) do
      within release_path do
        with path: "#{fetch(:release_path)}vendor/wp-cli/wp-cli/bin:$PATH" do
          execute :wp, "db export px-landing.sql --path=web/wp"
          download! "#{release_path}/px-landing.sql", "px-landing.sql"
          execute :rm, "#{release_path}/px-landing.sql"
        end
      end
      run_locally do
        execute "mv px-landing.sql ~/Downloads/"
      end
    end
  end
  desc "Push the local database to remote"
  task :push do
    on roles(:web) do
      within release_path do
        with path: "#{fetch(:release_path)}vendor/wp-cli/wp-cli/bin:$PATH" do
          upload! "#{File.expand_path File.dirname(__FILE__)}/../px-landing.sql", "#{release_path}/px-landing.sql"
          execute :wp, "db import px-landing.sql --path=web/wp"
          execute :rm, "#{release_path}/px-landing.sql"
        end
      end
      run_locally do
        execute :rm, "px-landing.sql"
      end
    end
  end
end

namespace :deploy do
  desc 'Setup a new project with files and db'
  task :setup do
    on roles(:web) do  
      if test "[ -d #{fetch(:deploy_to)} ]"
        error 'Sorry, this project already exists'
        exit 1
      end
    end
    dbpasw = ""
    invoke "#{scm}:check"
    invoke 'deploy:check:directories'
    invoke 'deploy:check:linked_dirs'
    invoke 'deploy:check:make_linked_dirs'
    invoke 'deploy:check:make_linked_files'
    invoke 'deploy'
    run_locally do
      dbpasw = capture "echo $(awk /DB_PASSWORD/ #{File.expand_path File.dirname(__FILE__)}/../.env)"
      dbpasw = dbpasw.split('=')[1]
      info "#{dbpasw}"
      with path: "$(pwd)/vendor/wp-cli/wp-cli/bin:/usr/local/bin:$PATH" do
        execute :wp, "db export px-landing.sql --path=web/wp"
      end
    end
    on roles(:web) do
      info "#{dbpasw}"
      execute "#{fetch(:stage_script)}/db.sh #{fetch(:application)} #{dbpasw}"
    end
    invoke 'db:push'
  end

  namespace :check do
    desc 'Create the linked files'
    task :make_linked_files do
      next unless any? :linked_files
      on release_roles :all do |host|
        linked_files(shared_path).each do |file|
          if "#{file}".include? ".htaccess"
            upload! "#{File.expand_path File.dirname(__FILE__)}/../web/.htaccess", file
          end  
          if "#{file}".include? ".env"
            upload! "#{File.expand_path File.dirname(__FILE__)}/../.env", file
            execute :sed, "'s/development/staging/g' #{file} > /tmp/.env-tmp"
            execute :mv, "/tmp/.env-tmp #{file}"
            execute :sed, "'s/.dev/.stage.bcon.io/g' #{file} > /tmp/.env-tmp"
            execute :mv, "/tmp/.env-tmp #{file}"
            execute :sed, "'s/127.0.0.1/localhost/g' #{file} > /tmp/.env-tmp"
            execute :mv, "/tmp/.env-tmp #{file}" 
          end
        end
      end
    end
  end
end
