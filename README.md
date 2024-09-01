# cool id

gem for rails apps to generates string ids with a prefix, followed by a [nanoid](https://zelark.github.io/nano-id-cc/). similar to the ids you see in stripe's api. also able to lookup any record by id, similar to rails' globalid. there's an [introductory blog post](https://schpet.com/note/cool-id) explaining why i made this.

```ruby
class User < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "usr"
end

User.create!(name: "...").id
# => "usr_vktd1b5v84lr"
```

lookup any record by its id

```ruby
CoolId.locate("usr_vktd1b5v84lr")
# => #<User id: "usr_vktd1b5v84lr", name: "John Doe">
```

and generate ids without creating a record

```ruby
# generate an id, e.g. for batch inserts or upserts
User.generate_cool_id
# => "usr_vktd1b5v84lr"
```

you can use cool_id with a separate field, keeping the default primary key:

```ruby
class Product < ActiveRecord::Base
  include CoolId::Model
  cool_id prefix: "prd", id_field: :public_id
end

product = Product.create!(name: "Cool Product")
product.id  # => 1 (or another integer)
product.public_id  # => "prd_vktd1b5v84lr"

# You can still use CoolId.locate with the public_id
CoolId.locate("prd_vktd1b5v84lr")  # => #<Product id: 1, public_id: "prd_vktd1b5v84lr", name: "Cool Product">
```

this approach allows you to keep your primary key as an auto-incrementing integer while still benefiting from CoolId's functionality. it's particularly useful when you want to expose a public identifier that's separate from your internal primary key.

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

parsing ids

```ruby
parsed = CoolId.parse("usr_vktd1b5v84lr")
# => #<struct CoolId::Id key="vktd1b5v84lr", prefix="usr", id="usr_vktd1b5v84lr", model_class=User>

parsed.model_class
# => User
```


## installation

add cool_id to your Gemfile:

```bash
bundle add cool_id
```

```ruby
gem "cool_id"
```

don't want another dependency? copy it into your project:

```
mkdir -p app/lib
curl https://raw.githubusercontent.com/schpet/cool_id/main/lib/cool_id.rb -o app/lib/cool_id.rb
```

### adding cool_id to a single model

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
