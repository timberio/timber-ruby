# 🌲 Timber - Master your Ruby apps with structured logging

<p align="center" style="background: #140f2a;">
<a href="http://files.timber.io/images/readme-interface.gif"><img src="http://files.timber.io/images/readme-interface.gif" width="100%" /></a>
</p>

[![ISC License](https://img.shields.io/badge/license-ISC-ff69b4.svg)](LICENSE.md)
[![CircleCI](https://circleci.com/gh/timberio/timber-ruby.svg?style=shield&circle-token=:circle-token)](https://circleci.com/gh/timberio/timber-ruby/tree/master)
[![Coverage Status](https://coveralls.io/repos/github/timberio/timber-ruby/badge.svg?branch=master)](https://coveralls.io/github/timberio/timber-ruby?branch=master)
[![Code Climate](https://codeclimate.com/github/timberio/timber-ruby/badges/gpa.svg)](https://codeclimate.com/github/timberio/timber-ruby)
[![View docs](https://img.shields.io/badge/docs-viewdocs-blue.svg?style=flat-square "Viewdocs")](http://www.rubydoc.info/github/timberio/timber-ruby)


---

👉 **Timber is in beta testing, if interested in joining, please email us at
[beta@timber.io](mailto:beta@timber.io)**

---

Still logging raw text? Timber solves logging so you don't have to. It's a complete *structured*
logging solution that you can setup in minutes.

To learn more, checkout out [timber.io](https://timber.io).


## Installation

1. *Add* the `timber` gem in `Gemfile`:

  ```ruby
  # Gemfile

  gem 'timber'
  ```

2. *Install* the `Timber::Logger` in `config/environments/production.rb`:

  ```ruby
  # config/environments/production.rb

  # config.log_formatter = ::Logger::Formatter.new # <--------------------------- REMOVE ME
  # config.logger = ActiveSupport::TaggedLogging.new(logger) # <----------------- REMOVE ME

  config.logger = ActiveSupport::TaggedLogging.new(Timber::Logger.new(STDOUT)) # <-- ADD ME
  ```

---

<details><summary><strong>Prefer to see an example pull request?</strong></summary><p>

Checkout our the [Timber install example pull request](https://github.com/timberio/ruby-rails-example-app/pull/1/files)

---

</p></details>

<details style="margin-bottom: 100px"><summary><strong>Not using Rails?</strong></summary><p>

No problem! You can easily install Timber following these steps:

1. *Insert* the Timber probes:

  This should be executed *immediately after* you have required your dependencies.

  ```ruby
  Timber::Probes.insert!
  ```

2. *Add* the Rack middlewares:

  This should be included where you build your `Rack` application. Usually `config.ru`:

  ```ruby
  # Most likely config.ru

  Timber::RackMiddlewares.middlewares.each do |m|
    use m
  end
  ```

2. *Instantiate* the Timber logger:

  This should be *globally* available to your application:

  ```ruby
  logger = Timber::Logger.new(STDOUT)
  ```

---

</p></details>

<div style="margin-bottom: 50px"></div>


## Send your logs (choose one)

<details><summary><strong>Heroku (log drains)</strong></summary><p>

The recommended strategy for Heroku is to setup a
[log drain](https://devcenter.heroku.com/articles/log-drains). To get your Timber log drain URL:

👉 **[Add your app to Timber](https://app.timber.io)**

---

</p></details>

<details><summary><strong>All other platforms (Network / HTTP)</strong></summary><p>

1. *Specify* the Timber Network logger backend in `config/environments/production.rb`:

  Replace any existing `config.logger =` calls with:

  ```ruby
  # config/environments/production.rb (or staging, etc)

  network_log_device = Timber::LogDevices::Network.new(ENV['TIMBER_LOGS_KEY'])
  config.logger = Timber::Logger.new(network_log_device) # <-- Use network_log_device instead of STDOUT
  ```

2. Obtain your Timber API :key: by **[adding your app in Timber](https://app.timber.io)**.

3. Assign your API key to the `TIMBER_LOGS_KEY` environment variable.

</p></details>

<details><summary><strong>Advanced setup (syslog, file tailing agent, etc)</strong></summary><p>

Checkout our [docs](https://timber.io/docs) for a comprehensive list of install instructions.

</p></details>


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

Tags provide a quick way to identify logs. They work just like any tagging system.
In the context of logging, they prevent obstructing the log message to
accomplish the same thing, while also being a step down from creating a classified custom
event. If the event is meaningful in any way, we recommend creating a custom event.

```ruby
logger.info(message: "My log message", tag: "tag")

# My log message @metadata {"level": "info", "tags": ["tag"], "context": {...}}
```

Multiple tags:

```ruby
logger.info(message: "My log message", tags: ["tag1", "tag2"])

# My log message @metadata {"level": "info", "tags": ["tag1", "tag2"], "context": {...}}
```

Using `ActiveSupport::TaggedLogging`? It works with that as well:

```ruby
logger.tagged("tag") do
  logger.info(message: "My log message", tags: ["important", "slow"])
end

# My log message @metadata {"level": "info", "tags": ["tag"], "context": {...}}
```

* In the Timber console use the query: `tags:tag`.

---

</p></details>

<details><summary><strong>Timings</strong></summary><p>

Timings allow you to easily capture one-off timings in your code; a simple
way to benchmark code execution:

```ruby
start = Time.now
# ...my code to time...
time_ms = (Time.now - start) * 1000
logger.info(message: "Task complete", tag: "my_task", time_ms: time_ms)

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
  Logger.warn message: "Payment rejected", payment_rejected: {customer_id: "abcd1234", amount: 100, reason: "Card expired"}

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

<details><summary><strong>What are the benefits of using Timber?</strong></summary><p>

1. **Data quality.** The usefulness of your logs starts here. This is why we ship libraries that
   structure logs from *within* your application; a fundamental difference from parsing. Not only
   is it much more stable, but we can include data you couldn't obtain otherwise.
2. **Human readability.** Structuring your logs doesn't mean they have to be unreadable. Timber
   *augments* your logs with structured data. Meaning we do not alter the original log message,
   we simply attach metadata to it. And our console is specifically designed to give you access
   to this data, without compromising readability. 😮
3. **Reliable downstream consumption.** All log events adhere to a
   [normalized, shared, schema](https://github.com/timberio/log-event-json-schema) that follows
   [semantic versioning](http://semver.org/) and goes through a [standard release process](https://github.com/timberio/log-event-json-schema/releases).
   This means you can *rely* on the structure of your logs and interact consistently with them
   across apps of any language: queries, graphs, alerts, and other downstream consumers.
4. **Zero risk of code debt or lock-in.** Logging is a standard that has been around since the dawn
   of computers. It's built into every language, framework, and library. Timber adheres strictly
   to the default `Logger` interface. There are no special APIs, and no need to pepper your app
   with Timber specific code. It's just better logging. If you choose to stop using Timber, you
   can do so without consequence.
5. **Long term retention.** Timber is designed on modern big-data principles. As a result, we can
   offer 6+ months of retention at prices cheaper than alternatives offering <1 month.
   This allows you to unlock your logs for purposes beyond debugging.

---

</p></details>

<details><summary><strong>What specifically does the Timber library do?</strong></summary><p>

1. Captures and structures your framework and 3rd party logs. (see next question)
2. Adds useful context to every log line. (see next question)
3. Allows you to easily add tags and timings to log. (see [Usage](#usage))
4. Provides a framework for logging custom structured events. (see [Usage](#usage))
5. Offers transport strategies to [send your logs](#send-your-logs) to the Timber service.

---

</p></details>

<details><summary><strong>What events does Timber capture & structure for me?</strong></summary><p>

Out of the box you get everything in the [`Timber::Events`](lib/timber/events) namespace:

1. [Controller Call Event](lib/timber/events/controller_call.rb)
2. [Exception Event](lib/timber/events/exception.rb)
3. [HTTP Client Request Event (net/http outgoing)](lib/timber/events/http_client_request.rb)
4. [HTTP Client Response Event (resposne from net/http outgoing)](lib/timber/events/http_client_response.rb)
5. [HTTP Server Request Event (incoming client request)](lib/timber/events/http_server_request.rb)
6. [HTTP Server Response Event (response to incoming client request)](lib/timber/events/http_server_response.rb)
7. [SQL Query Event](lib/timber/events/sql_query.rb)
8. [Template Render Event](lib/timber/events/template_render.rb)
9. ...more coming soon, [file an issue](https://github.com/timberio/timber-ruby/issues) to request.

We also add context to every log, everything in the [`Timber::Contexts`](lib/timber/contexts)
namespace. Context is structured data representing the current environment when the log line was
written. It is included in every log line. Think of it like join data for your logs:

1. [HTTP Context](lib/timber/contexts/http.rb)
2. [Organization Context](lib/timber/contexts/organization.rb)
3. [Process Context](lib/timber/contexts/process.rb)
4. [Server Context](lib/timber/contexts/server.rb)
5. [Runtime Context](lib/timber/contexts/runtime.rb)
5. [User Context](lib/timber/contexts/user.rb)
6. ...more coming soon, [file an issue](https://github.com/timberio/timber-ruby/issues) to request.

---

</p></details>

<details><summary><strong>What about my current log statements?</strong></summary><p>

They'll continue to work as expected. Timber adheres strictly to the default `::Logger` interface
and will never deviate in *any* way.

In fact, traditional log statements for non-meaningful events, debug statements, etc, are
encouraged. In cases where the data is meaningful, consider [logging a custom event](#usage).

</p></details>


---

<p align="center" style="background: #221f40;">
<a href="http://github.com/timberio/timber-ruby"><img src="http://files.timber.io/images/ruby-library-readme-log-truth.png" height="947" /></a>
</p>