# cool_id

a gem for rails that generates string primary key ids for active record models with a per-model prefix followed by a nanoid. 

```ruby
class User < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "usr"
end

User.create!(name: "...").id
# => "usr_vktd1b5v84lr"
```

it can also lookup records similar to global id:

```ruby
CoolId.locate("usr_vktd1b5v84lr")
# => #<User id: "usr_vktd1b5v84lr", name: "John Doe">
```

and parse ids

```ruby
parsed = CoolId.parse("usr_vktd1b5v84lr")
# => #<struct CoolId::Id key="vktd1b5v84lr", prefix="usr", id="usr_vktd1b5v84lr", model_class=User>

parsed.model_class
# => User
```

and generate ids without creating a record

```ruby
# generate an id, e.g. for batch inserts or upserts
User.generate_cool_id
# => "usr_vktd1b5v84lr"

```

it takes parameters to change the alphabet or length

```ruby
class Customer < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "cus", alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", length: 8
end

Customer.create!(name: "...").id
# => "cus_UHNYBINU"
```

and these can be configured globally

```ruby
CoolId.configure do |config|
  config.separator = "-"
  config.alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  config.length = 8
end
```

## installation

add cool_id to your Gemfile:

```bash
bundle add cool_id
```

```ruby
gem "cool_id"
```

### using cool_id in one model

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

### using cool_id on all models

you have drank the coolaid. setup rails to use string ids on all new generated migrations

```ruby
# config/initializers/generators.rb
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :string
end
```

then setup `ApplicationRecord` to include cool id and ensure it's setup in classes that inherit from it

```ruby
# app/models/application_record.rb
class ApplicationRecord < ActiveRecord::Base
  include CoolId::Model
  primary_abstract_class
  enforce_cool_id_for_descendants
end
```

### graphql

if you use the graphql ruby node interface, you can implement [object identification](https://graphql-ruby.org/schema/object_identification)


```ruby
# app/graphql/app_schema.rb
class AppSchema < GraphQL::Schema
  def self.id_from_object(object, type_definition, query_ctx)
    object.id
  end

  def self.object_from_id(id, query_ctx)
    CoolId.locate(id)
  end
end
```
