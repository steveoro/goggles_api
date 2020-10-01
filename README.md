# Goggles API README

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

- GogglesDb base engine (repo currently private)
- JWT for session handling


## Configuration

TODO

### Suggested dependancies:

*For editing & browsing API Blueprints:*

- VisualStudio Code, with API Blueprint parser & preview: the extensions should also pre-install Aglio, the HTML renderer for the blueprints; add also a JSON prettyfier, plus any other relevant & VSCode-suggested extension while you're at it. (Ruby, Rails, MariaDB/MySQL & Docker)

- Hercule, for managing the API document split among multiple files. Install it globally with:

```bash
$> sudo npm install -g hercule
```


## Database creation

TODO


## Database initialization

TODO


## How to run the test suite

TODO


## Services (job queues, cache servers, search engines, etc.)

TODO


## Deployment instructions

TODO


## Contributing
1. Clone the project
2. Make a pull request based on the branch most relevant to you
3. Await the PR's review by the maintainers


## License
The application is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
