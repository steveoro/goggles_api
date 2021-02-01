# frozen_string_literal: true

#
# = Version module
#
#   - version:  7.075
#   - author:   Steve A.
#
#   Semantic Versioning implementation.
module Version
  # Framework Core internal name.
  CORE    = 'C7'

  # Major version.
  MAJOR   = '7'

  # Minor version.
  MINOR   = '075'

  # Current build version.
  BUILD   = '20210201'

  # Full versioning for the current release.
  FULL    = "#{MAJOR}.#{MINOR}.#{BUILD} (#{CORE})"

  # Compact versioning label for the current release.
  COMPACT = "#{MAJOR.gsub('.', '')}#{MINOR}"

  # Current internal DB version (independent from migrations and framework release)
  DB      = '1.70.03'
end
