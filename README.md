# Yogurt

👋 Hey. This Rubygem is a GraphQL client, written using Sorbet. It lets you write GraphQL queries that are colocated with
your code, and it generates strongly-typed classes for the results using Sorbet. The general idea is that if you’re using
Sorbet to help avoid errors in your code, it’d be nice to extend that to data retrieved from GraphQL API’s.

This gem is still in a fairly early stage of development. It doesn’t supported named fragments. And I probably got a lot
of the decisions wrong in building it. So at some point, I’ll likely revisit those decisions and make substantial changes.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'yogurt'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install yogurt

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/theorygeek/yogurt.
