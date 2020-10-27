# Goggles API README

[![Build Status](https://steveoro.semaphoreci.com/badges/goggles_api/branches/master.svg)](https://steveoro.semaphoreci.com/projects/goggles_api)


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

## Requires

- Ruby 2.6+
- Rails 6+
- MySql


## System dependencies

- GogglesDb base engine, core 7+
- JWT for session handling


## Configuration

TODO


## Audit log

The Audit log is stored inside `log/api_audit.log`.
The Logger instance will split it and keep the latest 10 files of 1 MB each.


## Suggested dependencies:

*For editing & browsing API Blueprints:*

- VisualStudio Code, with API Blueprint parser & preview: the extensions should also pre-install Aglio, the HTML renderer for the blueprints; add also a JSON prettyfier, plus any other relevant & VSCode-suggested extension while you're at it. (Ruby, Rails, MariaDB/MySQL & Docker)

- Hercule, for managing the API document split among multiple files. Install it globally with:

```bash
$> sudo npm install -g hercule
```


## Database setup

You'll need a proper DB for both the test suite and the local development.

GogglesDb, among others, adds these tasks:

- `db:dump`: dumps current Rails environment DB;
- `db:rebuild`: restores any *.sql.bz2 dump file stored in `db/dump`, provided it is a DB dump without any DB namespaces in it. (No `USE` or `CREATE` database statements)

If you don't have a proper test seed dump, either ask Steve A. nicely for one, or build one yourself by force-loading the SQL structure file after resetting the current DB:

```bash
$> rails db:reset
$> rails structure:load
```

Then, you'll need to use the Factories in spec/factories to create fixtures.

A fully randomized `seed.rb` script is still a work-in-progress. Contributions are welcome.



## How to run the test suite

Although builds are automatically launched remotely on any `push`, for any branch or pull-request, make sure the test suite is locally green before pushing changes, in order to save build machine time and not clutter the build queue with tiny commits.

For local testing, just keep your Guard friend running in the background, in a dedicated console:

```bash
$> guard
```

As of Rails 6.0.3, most probably there are issues with the combined usage of Guard, Spring together with the new Zeitwerk mode for constant autoloading & reloading during the Brakeman checks: the `brakeman` plugin for Guard doesn't seem to notice actual changes in the source code, even when you fix or create issues (or maybe it's just a combined mis-configuration).

In any case, although the Guard plugin for Brakeman runs correctly at start, it's always better to re-run the `brakeman` checks before pushing the changes to the repository with:

```bash
$> bundle exec brakeman -Aq
```

_Please, commit & push any changes only when the test suite is :green:._


## Services (job queues, cache servers, search engines, etc.)

TODO


* * *


## Setup as individual Docker containers

Beside its "normal" installation as a Rails application, the repository contains a `Dockerfile` for configuring app deployment and usage as a Docker container. This relies on another separated container for the database which can be created with the steps that follow.

Instead of a full-blown MySQL/MariaDB installation on localhost, it's also possible to use the DB container for the cloned repository like the containerized version of the app.

See also ["Setup as a composed Docker service"](#Setup_as_a_composed_Docker_service) below for a more automated approach of both containers.



## Docker CLI login:

In order to push & pull _unlimited_ image tags from the Docker Registry you'll need to be logged-in, because the Docker Registry currently limits the number of anonymous image pulls that can be done during a certain time span.

Logging into Docker from the command line is not required for basic usage & setup but it may be necessary during periods of frequent updates to the base source repo.

The Docker Engine can keep user credentials in an external credentials store, such as the native keychain of the operating system. Using an external store is more secure than storing credentials in the plain-JSON Docker configuration file. (You'll get a warning if you log-in with plain-text credentials.)

In case you don't have a CLI password-manager, you can try [`pass`](https://github.com/docker/docker-credential-helpers/release) or use any D-Bus-based alternative (usually under KDE) or the Apple MacOS keychain or the MS Windows Credential Manager.

Under Ubuntu:

1. Install `pass` as password manager:

```bash
$> sudo apt-get install pass
```

2. You'll need the Docker helper that interfaces with the `pass` commands. For that, download, extract, make executable, and move `docker-credential-pass` (which is currently at v. 0.6.3):

```bash
$> wget https://github.com/docker/docker-credential-helpers/releases/download/v0.6.3/docker-credential-pass-v0.6.3-amd64.tar.gz && tar -xf docker-credential-pass-v0.6.3-amd64.tar.gz && chmod +x docker-credential-pass && sudo mv docker-credential-pass /usr/local/bin/
```

3. Create a new `gpg2` key:

```bash
$> gpg2 --gen-key
```

4. Follow prompts from the gpg2 utility. (Enter actual name, email & passphrase)

5. Initialize pass using the newly created key:

```bash
$> pass init "<Your Name>"
```

6. You'll need to add the credentials store (`"credStore": "pass"`) in `$HOME/.docker/config.json` to tell the docker engine to use it. The value of the config property should be the suffix of the program to use (i.e. everything after the downloaded helper name `docker-credential-`).

In our example (using `pass` as storage & `docker-credential-pass` as helper) you can create the `$HOME/.docker/config.json` file manually:

```json
{
  "credsStore": "pass"
}
```

Alternatively, you can also add the `"credStore": "pass"` to the docker config using a single `sed` command:

```bash
$> sed -i '0,/{/s/{/{\n\t"credsStore": "pass",/' ~/.docker/config.json
```

7. Log out with `docker logout` if you are currently logged in (this will also remove any previously plain-text credentials from the configuration file).

Login to docker to store the credentials. Use the correct username & omit the password from the command line. When you’re prompted for a password, enter the secret Docker authorization token instead.

_(The secret Docker token is currently available only inside our :key: config channel on Slack)_

```bash
$> docker login --username steveoro
```

On the first image pull the passphrase for the PGP key will be asked. If you are using a system-wide password manager and store the passphrase, you shouldn't be bothered anymore on any subsequent pull or push.

Ref.:
- [Docker engine credentials store](https://docs.docker.com/engine/reference/commandline/login/#credentials-store)
- [Passwordstore](https://www.passwordstore.org/)
- [issue on GitHub](https://github.com/docker/docker-credential-helpers/issues/102).


* * *

## DB container usage (MySql/MariaDB):

Check the already existing local Docker images with `docker images`.

Download & pull the latest MySql/MariaDb container if it's missing. For MySQL:

```bash
$> docker pull mysql:latest
```

Or, for MariaDB:

```bash
$> docker pull mariadb:10.3.25
```

Run or create the container in foreground by specifying:

- your own `My-Super-Secret-Pwd` for the MySql/MariaDb `root` user;
- use `goggles` or `goggles_development` as the actual database name, depending on the environment or purpose;
- use something like `~/Projects/goggles_db.vol` as local volume folder to be mounted for the DB data, with the full path to the local data volume where the database container is supposed to store the DB files (don't forget to `mkdir ~/Projects/goggles_db.vol` first if it's a new folder);
- the published port mapping `127.0.0.1:33060:3306` will bind port 3306 of the container to localhost's 33060. **(*)**

For consistency & stability we'll stick with the current MariaDb version, tagged 10.3.25.

Create a new container from the base image with:

```bash
$> docker run --name goggles-db -e MYSQL_DATABASE=goggles_development \
     -e MYSQL_ROOT_PASSWORD="My-Super-Secret-Pwd" \
     -v ~/Projects/goggles_db.vol:/var/lib/mysql \
     -p 127.0.0.1:33060:3306 mariadb:10.3.25 \
     --character-set-server=utf8mb4 \
     --collation-server=utf8mb4_unicode_ci
```

Eventually (as soon as you'll feel confident with the container setup) you'll want to add a `-d` parameter to the run statement before the image name for background/detached mode execution. (`docker run -d ...`)

_Note that this **(*)** published entry port will be reachable by TCP with an IP:PORT mapping, while any other existing MySQL service already running on localhost will remain accessible though the usual socket PID file_. (So you can have both.)

More precisely, the DB container can be reached **_from another container_** using its Docker network name (usually defined inside `docker-compose.yml`) and its _internal_ port (not the one published on localhost).

Whereas, the same DB container service can be accessed **_from localhost_** using the localhost IP (0.0.0.0) with its _published port_, forcing a TCP/IP connection (not using sockets) with the `host` parameter.


Check the running containers with:

```bash
$> docker ps -a
```


When in detached mode, you can check the console logs with a:

```bash
$> docker logs --follow goggles-db
```

Stop the container with CTRL-C if running in foreground; or from another console (when in detached mode) with:

```bash
$> docker stop goggles-db
```


In case of need, remove old stopped containers with `docker rm CONTAINER_NAME_OR_ID` and their images with `docker rmi IMAGE_ID`.

Existing stopped containers can be restarted easily:

```bash
$> docker start goggles-db
```



### Connecting to the DB container with the MySQL client:

Two possibilities:

- Run the `mysql` client from within the **container** with an interactive shell:

  ```bash
  $> docker exec -it goggles-db sh -c 'mysql --password="My-Super-Secret-Pwd" --database=goggles_development'
  ```

- Run the `mysql` client from **localhost** (if the client is available) and then connect to the service container using the _IP protocol_ and the correct published port:

  ```bash
  $> mysql --host=0.0.0.0 --port=33060 --user=root --password="My-Super-Secret-Pwd" --database=goggles_development
  ```



### Restoring the whole DB from existing backups:

Four basic steps:

1. get the DB dump in SQL format
2. drop the existing DB when not empty
3. recreate the DB
4. execute the script

Assuming we have a compressed dump located at `~/Projects/goggles.docs/backup.db/goggles-backup.20201005.sql.bz2`, unzip the DB backup in the current folder:

```bash
$ bunzip2 -ck ~/Projects/goggles.docs/backup.db/goggles-backup.20201005.sql.bz2 > goggles-backup.sql
```

Drop & recreate from scratch the existing database (either way is fine):

- from within the **container**:

  ```bash
  $> docker exec -it goggles-db sh -c 'mysql --user=root --password="My-Super-Secret-Pwd" --execute="drop database if exists goggles_development; create database goggles_development;"'
  ```

- from **localhost** (if mysql client is available), connect to the service container using the _IP protocol_ and the correct published port:

  ```bash
  $> mysql --host=0.0.0.0 --port=33060 --user=root --password="My-Super-Secret-Pwd" \
           --execute="drop database if exists goggles_development; create database goggles_development;"
  ```

Execute the script (again, choose your flavour):

If your SQL backup involves a single DB and contains a `USE DATABASE <db_name>` somewhere at the beginning, you'll need to remove that to have a truly DB-independent script (otherwise, the specified `--database=` parameter won't have any effect).

- from within the **container**:

  ```bash
  $> docker exec -it goggles-db sh -c 'mysql --user=root --password="My-Super-Secret-Pwd" --database=goggles_development' < ./goggles-backup.sql
  ```

- from **localhost**:

  ```bash
  $> mysql --host=0.0.0.0 --port=33060 --database=goggles_development --user=root \
           --password="My-Super-Secret-Pwd" < ./goggles-backup.sql
  ```

Reconnect to the MySQL client & check that it all went well:

```sql
MariaDB [goggles_development]> show tables;

--- snip ---

MariaDB [goggles_development]> desc users;

--- snip ---

```

Delete the uncompressed dump in the current folder when done.



#### Creating new DB backup dumps:

Two possibilities:

- from within the **container**:

  ```bash
  $> docker exec -it goggles-db sh -c 'mysqldump --user=root --password="My-Super-Secret-Pwd" -l --triggers --routines -i --skip-extended-insert --no-autocommit --single-transaction goggles_development' | bzip2 -c > goggles_development-backup.sql.bz2
  ```

- from **localhost** (if available):

  ```bash
  $> mysqldump --host=0.0.0.0 --port=33060 --user=root --password="My-Super-Secret-Pwd" \
               -l --triggers --routines -i --skip-extended-insert \
               --no-autocommit --single-transaction \
               goggles_development | bzip2 -c > goggles_development-backup.sql.bz2
  ```

If the first method fails (or it halts at the beginning of the dump, as if the DB was empty), usually a dump of all the databases shall do:

```bash
$ docker exec -it goggles-db sh -c 'mysqldump --user=root --password="My-Super-Secret-Pwd" -l --triggers --routines -i --skip-extended-insert --no-autocommit --single-transaction goggles_development --all-databases' | bzip2 -c > all_dbs-backup.sql.bz2
```


* * *


### API container:

While the DB container is a pretty standard MySQL/MariaDB container using a mounted external data volume, the main app container is custom built and supports different environments.

Dedicated _development_ & _production_ images are available [here](https://hub.docker.com/r/steveoro/goggles-api/tags), each one tagged by environment and version. The `latest` tag is used just for _production_.

Naming/Tag format: "[REPO_NAME]:[TAG_NAME]".

Existing images will be pulled automatically from the DockerHub registry with a `docker-compose up` if missing. The local container image(s) can be recreated from scratch each time you update the source code.

To build a new tagged image giving it - for example - a "0.1.1" tag, run:

- For _**development:**_
  ```bash
  $> docker build -t steveoro/goggles-api:dev-0.1.1 \
                  -f Dockerfile.dev .
  ```

- For _**production:**_
  ```bash
  $> docker build -t steveoro/goggles-api:prod-0.1.1 \
                  -t steveoro/goggles-api:latest \
                  -f Dockerfile.prod .
  ```

Make sure you have a valid `.env` file that includes the DB password (customize `.env.example` before).



The easiest way to run the API container (automatically building or downloading missing images) is:

```bash
$> docker-compose up
```

Use `docker-compose up --build` to force rebuilding the composed service.



### Connecting to the API container:

- Execute an interactive shell inside the container with:

  ```bash
  $> docker exec -it goggles-api sh
  ```

- Enter directly the Rails console with:

  ```bash
  $> docker exec -it goggles-api sh -c 'rails c'
  ```



### Updating the API container image:

To update an image, simply create a new image for it (with `build`) and `tag` it with an existing name tag, or a new one (if you know what you're doing).

Re-tag an existing image with:

```bash
$> docker tag local-image:tag_name steveoro/goggles-api:tag_name
```

Push an updated, tagged image onto the Docker registry with:

```bash
$> docker push steveoro/goggles-api:tag_name
```



* * *



## Setup as a composed Docker service

The composed service definitions inside `docker-compose.yml` will take care of binding together the containers.

A simple `docker-compose up` will run the default _**development**_ configuration with its counterpart DB.

Most of the `docker-compose` sub-commands are a mirror copy of their Docker counter part, such as `build`, `logs`, `stop`, `exec`, `ps`, `images` and many more.

At a glance:

- `docker-compose up` to start (and automatically build, if not existing) the composed service
- `docker-compose up --build` to force rebuilding the service
- `docker-compose stop` to just stop the containers
- `docker-compose ps` to display the running (composed) containers
- `docker-compose down` to stop and also _remove_ the containers



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
