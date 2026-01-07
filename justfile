default:
    just -l -u

bump-version:
    #!/bin/bash
    set -e
    VERSION=$(changelog version latest)
    sed -i '' "s/VERSION = \".*\"/VERSION = \"$VERSION\"/" lib/cool_id/version.rb
    gem build cool_id.gemspec
    bundle install

    jj commit -m "chore: Release cool_id version $VERSION"
    jj bookmark set main -r @-
    jj tag set "v$VERSION" -r @-
    jj git push --bookmark main

    git push origin --tags

    echo "released v$VERSION, now run 'gem push cool_id-$VERSION.gem'"
