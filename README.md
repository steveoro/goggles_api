# Goggles API README

[![Build Status](https://steveoro.semaphoreci.com/badges/goggles_api/branches/master.svg)](https://steveoro.semaphoreci.com/projects/goggles_api)
[![Maintainability](https://api.codeclimate.com/v1/badges/ffc7f57dfb4ce9d73056/maintainability)](https://codeclimate.com/github/steveoro/goggles_api/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/ffc7f57dfb4ce9d73056/test_coverage)](https://codeclimate.com/github/steveoro/goggles_api/test_coverage)
[![codecov](https://codecov.io/gh/steveoro/goggles_api/branch/master/graph/badge.svg?token=A5WG7PJ9HF)](https://codecov.io/gh/steveoro/goggles_api)
[![Coverage Status](https://coveralls.io/repos/github/steveoro/goggles_api/badge.svg?branch=master)](https://coveralls.io/github/steveoro/goggles_api?branch=master)
![](https://api.kindspeech.org/v1/badge)

Wraps all main Goggles' API endpoints in a stand-alone application.

The endpoints allow an authorized account to manage:

- sessions
- swimmer data
- team data
- badge data
- meeting data
- meeting results
- meeting reservations
- lap times
- trainings & workout routines


## Wiki & HOW-TOs

Official Framework Wiki, [here](https://github.com/steveoro/goggles_db/wiki) (v. 7+)


## Requires

- Ruby 2.6+
- Rails 6+
- MariaDb 10.3.25+ or MySql equivalent version


## Dependencies

- [GogglesDb base engine](https://github.com/steveoro/goggles_db), core 7+
- JWT for session handling
- [Grape gem](https://github.com/ruby-grape/grape) for API definition

You may need to install the GogglesDb gem disabling the download of the embedded test dump with:

```bash
$> GIT_LFS_SKIP_SMUDGE=1 bundle install
```

Use the same parameter when updating the gem with `bundle update goggles_db`.

To obtain a valid anonymized test DB dump image, just install [`goggles_db`](https://github.com/steveoro/goggles_db) on localhost by itself.


## Configuration

All framework app projects (except for the mountable engines) handle multiple configurations for execution, development & deployment.

You can use them either as single composed containers or as full-blown local installations, but also in other mixed ways, be it the application running on localhost while accessing the DB inside a container or vice-versa.


### *Full Localhost* usage

- a MariaDb running server & client w/ `dev` libraries (tested & recommended); alternatively, an up-to-date MySQL installation.

Clone the repository on localhost and use it as you would with a normal Rails application.

In order to start development, you'll need to:

- obtain a valid `config/master.key` file;
- customize `config/database.yml.example` according to your local MySQL installation and save it as `config/database.yml`;
- customize `.env.example` (as above) and save it as `.env` in case you want to build the Docker containers;
- obtain a a valid compressed development or test seed (`.sql.bz2`) stored under `db/dump`; check out [Database setup](#database-setup).


### *Composed Container* usage

For usage as a composed Docker container service you won't need an actual installation of MySQL or MariaDB, although a client `mysql` installation is recommended in case you want to run SQL commands into the DB container from the localhost shell.

If you're using the orchestrated container, just choose a random password for the database in the `.env` file and follow the WiKi How-To:

- [Docker & docker-compose setup & usage with GogglesAPI as reference example](#) :construction:


### *Mixed cases* usage

The `Dockerfile`s & `docker-compose` YML files work with some assumptions throughout the framework about published ports between containers and the host which is running Docker.

For instance, by changing just the current Database port in your customized `database.yml` you could switch from a typical localhost MySQL install (port 3306 running on socket) to a containerized MySQL Database on the different port published on the service (port 33060 using IP protocol).


| Service | Default internal port | Default published port |
|---|---|---|
|  | _"inside" containers_ / `localhost` | _"outside" service_ => _to_ localhost |
Database (MariaDB/MySQL) | 3306 | 33060
Web app | 3000 | 8080

The current `staging` environment configuration is an example of the app running _locally_ while connecting to the `goggles-db` container service on localhost:33060. (See the dedicated paragraph below.)



## Audit log

The API Audit log is stored inside `log/api_audit.log`.
The Logger instance will split it and keep the latest 10 files of 1 MB each.



## Suggested tools & dependencies

*For editing & browsing API Blueprints:*

- VisualStudio Code, with API Blueprint parser & preview: the extensions should also pre-install Aglio, the HTML renderer for the blueprints; add also a JSON prettyfier, plus any other relevant & VSCode-suggested extension while you're at it. (Ruby, Rails, MariaDB/MySQL & Docker)

- Hercule, for managing the API document split among multiple files. Install it globally with:

```bash
$> sudo npm install -g hercule
```



## How to run the test suite


### A. Everything on _localhost_

For local testing, just keep your friend [Guard](https://github.com/guard/guard) running in the background, in a dedicated console:

```bash
$> guard
```

If you want to run the full test suite, just hit enter on the Guard console.

As of Rails 6.0.3, most probably there are some issues with the combined usage of Guard & Spring together with the new memory management modes in Rails during the Brakeman checks. These prevent the `brakeman` plugin for Guard to actually notice changes in the source code: the checks get re-run, but the result doesn't change. Or maybe it's just a combined mis-configuration.

In any case, although the Guard plugin for Brakeman runs correctly at start, it's always better to re-run the `brakeman` checks before pushing the changes to the repository with:

```bash
$> brakeman -c .brakeman.cfg
```

If you don't have a local test DB setup, check out [Database setup](#database-setup).

_Make sure you commit & push any changes only when the test suite is_ :green_heart:.


### B. Everything on _Docker containers_

Althought not optimized for testing, the `dev` composed service can be used to run RSpec, Rubocop or anything else, including Guard too.

Run the composed container in detached mode, then connect to its internal shell and run the tests:

```bash
$> docker-compose -f docker-compose.dev.yml up -d
$> docker-compose -f docker-compose.dev.yml exec app sh

/app # RAILS_ENV=test bundle exec rspec

/app # RAILS_ENV=test bundle exec rubocop

/app # RAILS_ENV=test bundle exec brakeman -q

/app # RAILS_ENV=test bundle exec guard
```

Inside the container, remember to:

- always prefix the usual commands with `bundle exec` (as in `bundle exec rails console`, ...) to reach the correct bundle (stored in `/usr/local/bundle`);
- override the default RAILS_ENV `development` for anything test-related.


* * *


## Dev Workflow _(for contributors)_

When you push a commit to the `master` branch, the build system will re-test everything you allegedly have already checked locally using Guard as described above.

The project uses a _full CI pipeline_ setup on Semaphore 2.0 (currently for the `master` branch only) that will promote a successful build into the Docker `latest` production-only image on DockerHub.

All other tagged Docker images will be auto-built by DockerHub itself, as soon as any specific branch has been _manually tagged_ as a _release_ from the GitHub UI. (Using GitHub release tags that respect semantic versioning, with format `MAJOR`.`MINOR`.`BUILD`)

Given this, avoid cluttering the build queue with tiny commits (unless these are hotfixes) and with something that hasn't been greenlit by a local run of the whole test suite: it's adamant that you don't push failing builds whenever possible.

Basically, remember to:

- login to docker from the console with `docker login` whenever you're using Docker for testing or development (in order to avoid pull/push threshold caps);
- always develop with a running `guard` in background;
- when you're ready to push, do a full test suite run (just to be sure);
- run also an additional Brakeman scan before the push as suggested above.


* * *


## Database setup

See [GogglesDb setup](https://github.com/steveoro/goggles_db#database-setup).

You'll need a proper DB for both the test suite and the local development.

Assuming we want the `test` environment DB up and running, you can either have:


### A. Everything on _localhost_

- Make sure you have a running MariaDB server & client installation.

- Given you have a valid `db/dump/test.sql.bz2` (the dump must be un-namespaced to be copied or renamed from any other environment - as those created by `db:dump` typically are), use the dedicated rake tasks:

```bash
$> bin/rails db:rebuild from=test to=test
$> RAILS_ENV=test bin/rails db:migrate
```

(It will take some time, depending of the dump size: sit back and relax.)


### B. Everything on _Docker containers_

If the DB container for the test environment still needs to be created or it's new, the `test` database will be either newly created and empty or even missing at all.

Start / build the DB container:

```bash
$> docker-compose -f docker-compose.dev.yml up goggles-db
```

WIP :construction:

If a local `mysql` client is available, recreate `goggles_test` from localhost:

 *** MISSING CREATE DATABASE from mysql ***

```bash
$> bunzip2 -ck ./db/dump/test.sql.bz2 > ./db/dump/test.sql

$> mysql --host=0.0.0.0 --port=33060 --user=root \
         --password="My-Super-Secret-Pwd" \
         --database=goggles_test < ./db/dump/test.sql

$> rm ./db/dump/test.sql
```

WIP :construction:

------------------------------- TODO

Create & run a new container from the base image with:

```bash
$> docker run --name goggles-db -e MYSQL_DATABASE=goggles_temp \
     -e MYSQL_ROOT_PASSWORD="My-Super-Secret-Pwd" \
     -v ~/Projects/goggles_db.vol:/var/lib/mysql \
     -p 127.0.0.1:33060:3306 mariadb:10.3.25 \
     --character-set-server=utf8mb4 \
     --collation-server=utf8mb4_unicode_ci
```


Connect to the container's DB with:

```bash
$> docker exec -it goggles-db sh -c 'mysql --password="My-Super-Secret-Pwd" --database=goggles_development'
```


Fill it with the seed dump with:

TODO

```bash
$> ...
$>
```


* * *


## Staging

Staging will use a custom copy of the `production` environment together with the database running on the production Docker image (tag: `latest`) of the composed service (DockerHub: `steveoro/goggles-api:latest`), minus the SSL enforcing (so that we can test that easily on localhost).

To recreate or restore a usable database with testing seeds, assuming:

1. you have a valid `test.sql.bz2` dump file stored under `db/dumps`;
2. the DB container `goggles-db` has been already built and already running;

Execute the dedicated task:

```bash
$> RAILS_ENV=staging rails db:rebuild from=test to=staging
```

Run the server on localhost with:

```bash
$> rails s -p 8080 -e staging
```

...Or the console with:

```bash
$> rails c -e staging
```


* * *


## Deployment instructions

TODO



* * *



## Contributing
1. Clone the project
2. Make a pull request based on the branch most relevant to you
3. Await the PR's review by the maintainers


## License
The application is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Supporting

Check out the "sponsor" button at the top of the page.
