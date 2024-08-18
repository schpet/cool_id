# cool_id

a gem for rails that generates string ids for active record models with a per-model prefix followed by a nanoid.

```ruby
class User < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "usr"
end

User.create!(name: "...").id
# => "usr_vktd1b5v84lr"

class Customer < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "cus", alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", length: 8
end

Customer.create!(name: "...").id
# => "cus-UHNYBINU"
```

it can also lookup records by ids, similar to global id:

```ruby
user = User.create!(name: "John Doe")
# => #<User id: "usr_vktd1b5v84lr", name: "John Doe">

CoolId.locate("usr_vktd1b5v84lr")
# => #<User id: "usr_vktd1b5v84lr", name: "John Doe">

# You can also parse the id without fetching the record
parsed = CoolId.parse("usr_vktd1b5v84lr")
# => #<struct CoolId::Id key="vktd1b5v84lr", prefix="usr", id="usr_vktd1b5v84lr", model_class=User>

parsed.model_class
# => User
```

## installation

```bash
bundle add cool_id
```

```ruby
gem "cool_id"
```

### per-model

use string ids when creating a table

```ruby
create_table :users, id: :string do |t|
  t.string :name
end
```

include the `CoolId::Model` concern in the active record model and set up a prefix

```ruby
class User < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "usr"
end
```

### all models

use string ids on all new generated migrations

```ruby
# config/initializers/generators.rb
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :string
end
```

setup `ApplicationRecord` to include cool id and ensure it's setup in classes that inherit from it

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  include CoolId::Model
  primary_abstract_class
  enforce_cool_id_for_descendants
end
```
