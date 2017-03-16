# 🌲 Timber - Log Better. Solve Problems Faster.

<p align="center" style="background: #140f2a;">
<a href="http://files.timber.io/images/readme-interface-5.gif"><img src="http://files.timber.io/images/readme-interface-5.gif" width="100%" /></a>
</p>

[![ISC License](https://img.shields.io/badge/license-ISC-ff69b4.svg)](LICENSE.md)
[![CircleCI](https://circleci.com/gh/timberio/timber-ruby.svg?style=shield&circle-token=:circle-token)](https://circleci.com/gh/timberio/timber-ruby/tree/master)
[![Coverage Status](https://coveralls.io/repos/github/timberio/timber-ruby/badge.svg?branch=master)](https://coveralls.io/github/timberio/timber-ruby?branch=master)
[![Code Climate](https://codeclimate.com/github/timberio/timber-ruby/badges/gpa.svg)](https://codeclimate.com/github/timberio/timber-ruby)
[![View docs](https://img.shields.io/badge/docs-viewdocs-blue.svg?style=flat-square "Viewdocs")](http://www.rubydoc.info/github/timberio/timber-ruby)

* [Timber website](https://timber.io)
* [Library documentation](https://hex.pm/packages/timber)
* [Support](mailto:support@timber.io)

## Overview

Timber improves your logs so you can solve issues faster. There are no agents, special APIs, or
locked away data; just better logging.

Timber works by automatically by turning your raw text logs into rich structured events. It
pairs with the [Timber Console](https://app.timber.io) to maximize your productivity, allowing
you to _quickly_ find what you need so that you get back to doing what you do.
With Timber you'll _always_ have the data you need to resolve issues.

To provide an example, Timber turns this:

```
Sent 200 in 45.ms
```

Into this:

```
Sent 200 in 45.2ms @metadata {"dt": "2017-02-02T01:33:21.154345Z", "level": "info", "context": {"user": {"id": 1}, "http": {"method": "GET", "host": "timber.io", "path": "/path", "request_id": "abcd1234"}}, "event": {"http_response": {"status": 200, "time_ms": 45.2}}}
```

Allowing you to run queries like:

1. `context.request_id:abcd1234` - View all logs generated for a specific request.
2. `context.user.id:1` - View logs generated by a specific user.
3. `type:exception` - View all exceptions with the ability to zoom out and view them in context (request, user, etc).
4. `http_server_response.time_ms:>=1000` - View slow responses with the ability to zoom out and view them in context (request, user, etc).
5. `level:error` - Levels in your logs, imagine that!


## Installation

1. In `Gemfile`, add the `timber` gem:

    ```ruby
    # Gemfile

    gem 'timber'
    ```

2. In your `shell`, run `bundle exec timber install`


## Usage

<details><summary><strong>Basic logging</strong></summary><p>

Use `Logger` as normal:

```ruby
logger.info("My log message")

# My log message @metadata {"level": "info", "context": {...}}
```

Timber will *never* deviate from the public `::Logger` interface in *any* way.

---

</p></details>

<details><summary><strong>Tagging logs</strong></summary><p>

Tags provide a quick way to categorize logs and make them easier to search:

```ruby
logger.info("My log message", tag: "tag")

# My log message @metadata {"level": "info", "tags": ["tag"], "context": {...}}
```

Multiple tags:

```ruby
logger.info("My log message", tags: ["tag1", "tag2"])

# My log message @metadata {"level": "info", "tags": ["tag1", "tag2"], "context": {...}}
```

Using `ActiveSupport::TaggedLogging`? It works with that as well:

```ruby
logger.tagged("tag") do
  logger.info("My log message", tags: ["important", "slow"])
end

# My log message @metadata {"level": "info", "tags": ["tag"], "context": {...}}
```

* In the Timber console use the query: `tags:tag`.

---

</p></details>

<details><summary><strong>Timing events</strong></summary><p>

Timings provid a simple way to time code execution:

```ruby
start = Time.now
# ...my code to time...
time_ms = (Time.now - start) * 1000
logger.info("Task complete", tag: "my_task", time_ms: time_ms)

# My log message @metadata {"level": "info", tags: ["my_task"], "time_ms": 54.2132, "context": {...}}
```

* In the Timber console use the query: `tags:my_task time_ms>500`
* The Timber console will also display this value inline with your logs. No need to include it
  in the log message, but you certainly can if you'd prefer.

---

</p></details>


<details><summary><strong>Custom events</strong></summary><p>

Custom events can be used to structure information about events that are central
to your line of business like receiving credit card payments, saving a draft of a post,
or changing a user's password. You have 2 options to do this:

1. Log a structured Hash (simplest)

  ```ruby
  Logger.warn "Payment rejected", payment_rejected: {customer_id: "abcd1234", amount: 100, reason: "Card expired"}

  # Payment rejected @metadata {"level": "warn", "event": {"payment_rejected": {"customer_id": "abcd1234", "amount": 100, "reason": "Card expired"}}, "context": {...}}
  ```

  * The hash can *only* have 2 keys: `:message` and "event type" key; `:payment_rejected` in this example.
  * Timber will keyspace your event data by the event type key passed.

2. Log a Struct (recommended)

  Defining structs for your important events just feels oh so good :) It creates a strong contract
  with down stream consumers and gives you compile time guarantees.

  ```ruby
  PaymentRejectedEvent = Struct.new(:customer_id, :amount, :reason) do
    def message; "Payment rejected for #{customer_id}"; end
    def type; :payment_rejected; end
  end
  Logger.warn PaymentRejectedEvent.new("abcd1234", 100, "Card expired")

  # Payment rejected @metadata {"level": "warn", "event": {"payment_rejected": {"customer_id": "abcd1234", "amount": 100, "reason": "Card expired"}}, "context": {...}}
  ```

* In the Timber console use queries like: `payment_rejected.customer_id:xiaus1934` or `payment_rejected.amount>100`
* For more advanced examples see [`Timber::Logger`](lib/timber.logger.rb).
* Also, notice there is no mention of Timber in the above code. Just plain old logging.

#### What about regular Hashes, JSON, or logfmt?

Go for it! Timber will parse the data server side, but we *highly* recommend the above examples.
Providing a `:type` allows timber to classify the event, create a namespace for the data you
send, and make it easier to search, graph, alert, etc.

```ruby
logger.info({key: "value"})
# {"key": "value"} @metadata {"level": "info", "context": {...}}

logger.info('{"key": "value"}')
# {"key": "value"} @metadata {"level": "info", "context": {...}}

logger.info('key=value')
# key=value @metadata {"level": "info", "context": {...}}
```

---

</p></details>

<details><summary><strong>Custom contexts</strong></summary><p>

Context is structured data representing the current environment when the log line was written.
It is included in every log line. Think of it like join data for your logs. For example, the
`http.request_id` field is included in the context, allowing you to find all log lines related
to that request ID, if desired. This is in contrast to *only* showing log lines that contain this
value.

1. Add a Hash (simplest)

  ```ruby
  Timber::CurrentContext.with({build: {version: "1.0.0"}}) do
    logger.info("My log message")
  end

  # My log message @metadata {"level": "info", "context": {"build": {"version": "1.0.0"}}}
  ```

  This adds data to the context keyspaced by `build`.

2. Add a Struct (recommended)

  Just like events, we recommend defining your custom contexts. It makes a stronger contract
  with downstream consumers.

  ```ruby
  BuildContext = Struct.new(:version) do
    def type; :build; end
  end
  build_context = BuildContext.new("1.0.0")
  Timber::CurrentContext.with(build_context) do
    logger.info("My log message")
  end

  # My log message @metadata {"level": "info", "context": {"build": {"version": "1.0.0"}}}
  ```

</p></details>


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

1. **No lock-in**. Timber is just _better_ logging. There are no agents or special APIs. This means
   no risk of vendor lock-in, code debt, or performance issues.
2. **Data quality.** Instead of relying on parsing alone, Timber ships libraries that structure
   and augment your logs from _within_ your application. Improving your log data at the source.
3. **Human readability.** Structuring your logs doesn't have to mean losing readability. Instead,
   Timber _augments_ your logs. For example: `log message @metadata {...}`. And when you view
   your logs in the [Timber console](https://app.timber.io), you'll see the human friendly messages
   with the ability to view the associated metadata.
4. **Sane prices, long retention**. Logging is notoriously expensive with low retention. Timber
   is affordable and offers _6 months_ of retention by default.
5. **Normalized schema.** Have multiple apps? All of Timber's libraries adhere to our
   [JSON schema](https://github.com/timberio/log-event-json-schema). This means queries, alerts,
   and graphs for your ruby app can also be applied to your elixir app (for example).

---

</p></details>

---

<p align="center" style="background: #221f40;">
<a href="http://github.com/timberio/timber-elixir"><img src="http://files.timber.io/images/ruby-library-readme-log-truth.png" height="947" /></a>
</p>