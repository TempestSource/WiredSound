# 1. Use the official Ruby 4.0.1 image
FROM ruby:4.0.1-slim AS base

# 2. Install system dependencies for MariaDB and Rails
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libmariadb-dev \
    curl \
    git \
    pkg-config \
    libyaml-dev \
    libffi-dev

# 3. Set the working directory
WORKDIR /rails

# 4. Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# 5. Copy the rest of the application code
COPY . .

# 6. Expose the Rails port
EXPOSE 3000

# 7. Default command to start the server
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]