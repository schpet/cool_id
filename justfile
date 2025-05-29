default:
    echo 'Hello, world!'

bump-version:
    #!/bin/bash
    set -e
    VERSION=$(changelog version latest)
    sed -i '' "s/VERSION = \".*\"/VERSION = \"$VERSION\"/" lib/cool_id/version.rb
    gem build cool_id.gemspec
    bundle install
    git add lib/cool_id/version.rb Gemfile.lock CHANGELOG.md
    # git commit -m "chore: Release cool_id version $VERSION"
    # git tag "v$VERSION"
