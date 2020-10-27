# frozen_string_literal: true

#
# = Local Deployment helper tasks
#
#   - (p) FASAR Software 2007-2020
#   - for Goggles framework vers.: 7.00
#   - author: Steve A.
#
#-- ---------------------------------------------------------------------------
#++

# [Steve, 20130808] The following will remove the task db:test:prepare
# to avoid having to wait each time a test is run for the db test to reset
# itself:
Rake::TaskManager.class_eval do
  def remove_task(task_name)
    @tasks.delete(task_name.to_s)
  end
end
Rake.application.remove_task 'db:test:prepare'

namespace :db do
  namespace :test do
    desc 'NO-OP task: not needed for this project (always safe to run, shouldn\'t affect the DB dump)'
    task :prepare do |t|
      # (Rewrite the task to *not* do anything you don't want)
      puts "This task shouldn't do anything for this Project: we are using DB dumps as base seed and the test DB uses transactional fixtures."
    end
  end
end
