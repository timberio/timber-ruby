# 🌲 Timber - Instant Ruby Structured Logging

[![ISC License](https://img.shields.io/badge/license-ISC-ff69b4.svg)](LICENSE.md)
[![Build Status](https://travis-ci.org/timberio/timber-ruby.svg?branch=master)](https://travis-ci.org/timberio/timber-ruby)
[![Code Climate](https://codeclimate.com/github/timberio/timber-ruby/badges/gpa.svg)](https://codeclimate.com/github/timberio/timber-ruby)
[![View docs](https://img.shields.io/badge/docs-viewdocs-blue.svg?style=flat-square "Viewdocs")](http://www.rubydoc.info/github/timberio/timber-ruby)

* [Timber website](https://timber.io)
* [Timber docs](https://timber.io/docs)
* [Library docs](http://www.rubydoc.info/github/timberio/timber-ruby)
* [Support](mailto:support@timber.io)


## Overview

Timber for Ruby solves structured logging so you don't have to. Go from raw text logs to rich
structured events with a single command and spend time focusing on your app, not logging.


## Installation

1. In `Gemfile`, add the `timber` gem:

    ```ruby
    gem 'timber', '~> 2.0'
    ```

2. In your `shell`, run `bundle install`

3. In your `shell`, run `bundle exec timber install`


## How it works

Timber's goal is to provide you with a best-in-class, _complete_ structured logging solution
without all of the decisions and effort to get setup. It does so in 3 ways:

<details><summary><strong>1. Automatically structures third-party and framework logs</strong></summary><p>

For example, Timber turns this familiar raw text log line:

```
Sent 200 in 45.2ms
```

Into a rich [`http_server_response` event](https://timber.io/docs/ruby/events-and-context/http-server-response-event/).

```
Sent 200 in 45.2ms @metadata {"dt": "2017-02-02T01:33:21.154345Z", "level": "info", "context": {"user": {"id": 1, "name": "Ben Johnson"}, "http": {"method": "GET", "host": "timber.io", "path": "/path", "request_id": "abcd1234"}}, "event": {"http_server_response": {"status": 200, "time_ms": 45.2}}}
```

Notice the above line not only has structured data about the log line itself, but it also contains
`context`, notably the [`user` context](https://timber.io/docs/ruby/events-and-context/user-context/).

Moreover, this data allows you to run powerful queries like:

1. `request_id:abcd1234` - View all logs generated for a specific request.
2. `user.id:1` - View logs generated by a specific user.
3. `type:http_server_response` - View specific events (exceptions, sql queries, etc)
4. `http_server_response.time_ms:>=1000` - View slow responses with the ability to zoom out and view them in context (request, user, etc).
5. `level:info` - Levels in your logs!

For a complete overview, see the [Timber for Ruby docs](https://timber.io/docs/ruby/overview/).

</p></details>

<details><summary><strong>2. Provides a simple API for logging structured data</strong></summary><p>

fdsfsdf

</p></details>

<details><summary><strong>3. Marries all of this with a simple and beautiful console</strong></summary><p>

fsdfds

</p></details>


## Usage

<details><summary><strong>Basic logging</strong></summary><p>

Use `Logger` as normal:

```ruby
logger.info("My log message")

# => My log message @metadata {"level": "info", "context": {...}}
```

---

</p></details>

<details><summary><strong>Custom events</strong></summary><p>

Custom events allow you to extend beyond events already defined in
the [`Timber::Events`](lib/timber/events) namespace.

```ruby
logger.warn "Payment rejected", payment_rejected: {customer_id: "abcd1234", amount: 100, reason: "Card expired"}

# => Payment rejected @metadata {"level": "warn", "event": {"payment_rejected": {"customer_id": "abcd1234", "amount": 100, "reason": "Card expired"}}, "context": {...}}
```

* Notice the `:payment_rejected` root key. Timber will classify this event as such.
* In the [Timber console](https://app.timber.io) use the query: `type:payment_rejected` or `payment_rejected.amount:>100`.
* See more details on our [custom events docs page](https://timber.io/docs/ruby/custom-events/)

---

</p></details>

<details><summary><strong>Custom contexts</strong></summary><p>

Context is additional data shared across log lines. Think of it like log join data.
Custom contexts allow you to extend beyond contexts already defined in
the [`Timber::Contexts`](lib/timber/contexts) namespace.

```ruby
logger.with_context(build: {version: "1.0.0"}) do
  logger.info("My log message")
end

# => My log message @metadata {"level": "info", "context": {"build": {"version": "1.0.0"}}}
```

* Notice the `:build` root key. Timber will classify this context as such.
* In the [Timber console](https://app.timber.io) use queries like: `build.version:1.0.0`
* See more details on our [custom contexts docs page](https://timber.io/docs/ruby/custom-contexts/)

</p></details>

<details><summary><strong>Metrics & Timings</strong></summary><p>

Aggregates destroy details, and with Timber capturing metrics and timings is just logging events.
Timber is built on modern big-data principles, it can calculate aggregates across terrabytes of
data in seconds. Don't reduce the quality of your data because the system processing
your data is limited.

Here's a timing example. Notice how Timber automatically calculates the time and adds the timing
to the message.

```ruby
timer = Timber::Timer.start
# ... code to time ...
logger.info("Processed background job", background_job: {time_ms: timer})

# => Processed background job in 54.2ms @metadata {"level": "info", "event": {"background_job": {"time_ms": 54.2}}}
```

Or capture any metric you want:

```ruby
logger.info("Credit card charged", credit_card_charge: {amount: 123.23})

# => Credit card charged @metadata {"level": "info", "event": {"credit_card_charge": {"amount": 123.23}}}
```

In Timber you can easily sum, average, min, and max the `amount` attribute across any interval
you desire.

</p></details>


## Configuration

Timber has taken great care to ensure most aspects of Timber are configurable or extendable
where necessary:

<details><summary><strong>Custom user context</strong></summary><p>

By default Timber automatically captures user context for some of the popular authentication
libraries (Devise, Omniauth, and Clearance). In cases where you Timber doesn't support
your strategy, or you want to customize it further you can do se easily:

```ruby
# config/initializers/timber.rb
Timber::Integrations::Rack::UserContext.custom_user_hash = lambda do |rack_env|
  user = rack_env['warden'].user
  if user
    {
      id: user.id, # unique identifier for the user, can be an integer or string,
      name: user.name, # identifiable name for the user,
      email: user.email, # user's email address
    }
  else
    nil
  end
end
```

</p></details>

<details><summary><strong>Lograge-ify</strong></summary><p>

Using [lograge](https://github.com/roidrage/lograge)? We've provided a convenience method that
configures Timber to behave in the same way. Internally it's just altering the Timber
configuration. Here's what it does:

1. Silences ActiveRecord SQL query and ActiveView template rendering logs.
2. Collapses HTTP request and response logs into a single event.
3. Sets the log format to logfmt.


```ruby
# config/initializers/timber.rb
Timber::Config.instance.logrageify()
```

That's it!

</p></details>

<details><summary><strong>Cherry pick & silence integrations</strong></summary><p>

You can disable Timber integrations entirely or simply silence them. Disabling is like
removing the code from Timber. The library will use it's defaults. Silencing ensures that library
does not log at all. This is partly how we accomplish the logrageify option above.

```ruby
# config/initializers/timber.rb

# Don't log any ActionViews template renders
Timber::Integrations::ActionView.silence = true

# Don't log any ActiveRecord SQL queries, period
Timber::Integrations::ActiveRecord.silence = true

# Don't touch ActionController, use the default log messages (don't structure them)
Timber::Integrations::ActionController.enabled = false
```

</p></details>

<br />
...and much more. For a comprehensive guide / list, please see [the configuration documentation]().


## Jibber-Jabber

<details><summary><strong>Which log events does Timber structure for me?</strong></summary><p>

Out of the box you get everything in the [`Timber::Events`](lib/timber/events) namespace.

We also add context to every log, everything in the [`Timber::Contexts`](lib/timber/contexts)
namespace. Context is structured data representing the current environment when the log line
was written. It is included in every log line. Think of it like join data for your logs.

---

</p></details>

<details><summary><strong>What about my current log statements?</strong></summary><p>

They'll continue to work as expected. Timber adheres to the default `Logger` interface.
Your previous logger calls will work as they always do.

In fact, traditional log statements for non-meaningful events, debug statements, etc, are
encouraged. In cases where the data is meaningful, consider [logging a custom event](#usage).

</p></details>

<details><summary><strong>How is Timber different?</strong></summary><p>

1. **It's just _better_ logging**. Nothing beats well structured raw data. And that's exactly
   what Timber aims to provide. There are no agents, special APIs, or proprietary data
   sets that you can't access.
2. **Improved log data quality.** Instead of relying on parsing alone, Timber ships libraries that
   structure and augment your logs from _within_ your application. Improving your log data at the
   source.
3. **Human readability.** Timber _augments_ your logs without sacrificing human readability. For
   example: `log message @metadata {...}`. And when you view your logs in the
   [Timber console](https://app.timber.io), you'll see the human friendly messages
   with the ability to view the associated metadata.
4. **Long retention**. Logging is notoriously expensive with low retention. Timber
   offers _6 months_ of retention by default with sane prices.
5. **Normalized schema.** Have multiple apps? All of Timber's libraries adhere to our
   [JSON schema](https://github.com/timberio/log-event-json-schema). This means queries, alerts,
   and graphs for your ruby app can also be applied to your elixir app (for example).

---

</p></details>

---

<p align="center" style="background: #221f40;">
<a href="http://github.com/timberio/timber-elixir"><img src="http://files.timber.io/images/ruby-library-readme-log-truth.png" height="947" /></a>
</p>