## Relevant Version History / current working features:

_Please, add the latest build info on top of the list; use Version::MAJOR only after gold release; keep semantic versioning in line with framework's_

- **0.3.07** [Steve A.] POST new city now requires both country & country_code to avoid invalid data with default 'IT'
- **0.3.06** [Steve A.] swimming_pool association in UserResult is no longer optional; minor refactorings
- **0.3.01** [Steve A.] improved structure for import_queues & helpers; data migrations & misc fixes
- **0.2.18** [Steve A.] upgraded gem set due to security fixes; added 'name' filtering parameter to /lookup endpoint; added endpoints, blueprints & specs for UserWorkshop, UserResult, UserLap, CategoryType, ImportQueue & APIDailyUsage
- **0.2.05** [Steve A.] bump versioning according to main application
- **0.1.93** [Steve A.] revised Docker builds & continuous deployment procedure
- **0.1.82** [Steve A.] default container port is now 8081
- **0.1.81** [Steve A.] restricted access for /user(s) endpoints; improved specs for maintenance mode
- **0.1.80** [Steve A.] re-synch w/ base engine (OAuth2 support for Facebook & Google logins for non-API requests)
- **0.1.76** [Steve A.] improved build setup; goggles_db re-synch'ed
- **0.1.75** [Steve A.] removed vulnerability in /lookup API endpoint; upgrade to Ruby 2.7.2; documentation updates
- **0.1.73** [Steve A.] all API endpoints for major entities done, minus GoggleCup, MeetingTeamScore, StandardTiming & misc personal & season records; updated license to be compliant with goggles_db gem
- **0.1.61** [Steve A.] API endpoints for Meetings reservations, events & programs
- **0.1.54** [Steve A.] API endpoints up to Meetings & entries (no events or results)
- **0.1.21** [Steve A.] API endpoints halfway through (DB Engine still missing all Meeting entities); CI pipeline setup & basic Docker builds (production deployment still postponed)
