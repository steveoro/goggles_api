FROM ruby:2.6.3-alpine
LABEL AUTHOR=steve.alloro@gmail.com
LABEL version="0.1"
ENV BUNDLER_VERSION=2.0.2
ENV INSTALL_PATH /app

RUN mkdir -p $INSTALL_PATH
RUN apk add --update --no-cache \
  binutils-gold \
  build-base \
  curl \
  file \
  g++ \
  gcc \
  git \
  less \
  libstdc++ \
  libffi-dev \
  libc-dev \
  linux-headers \
  libxml2-dev \
  libxslt-dev \
  libgcrypt-dev \
  make \
  mariadb-client \
  mariadb-dev \
  netcat-openbsd \
  nodejs \
  openssl \
  pkgconfig \
  python \
  tzdata \
  yarn

RUN gem install bundler -v 2.0.2
WORKDIR $INSTALL_PATH

# Image contents:
COPY . ./
RUN bundle config build.nokogiri --use-system-libraries
RUN bundle check || bundle install
RUN yarn install --check-files
COPY ./config/database.docker.yml ./config/database.yml

# Run as a specific user:
# ARG USER_ID
# ARG GROUP_ID
# RUN addgroup --gid $GROUP_ID user
# RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID user
# Correct ownership:
# RUN chown -R user:user $INSTALL_PATH
# USER $USER_ID

ENTRYPOINT ["./entrypoints/docker.sh"]
#------------------------------------------------------------------------------
