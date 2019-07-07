---
title: "Talk to My (Elixir) Agent"
date: 2016-10-07 13:21 UTC
---


> This post is one in a series about building a collaborative music app in Elixir and Elm called [Loops With Friends]. If you'd like to catch up, visit the [first post] in the series to learn all about it!

In the [previous post] in this series, we looked at how Elixir and Phoenix make supporting multiple client connections in our application straightforward.

The last and most complex feature on the back end of the [Loops With Friends] app is the balancing of the users in each channel topic, or "jam." This is where we depart from Phoenix's conveniences and start using an Elixir OTP server to hold application state.

## User Experience

The desired behavior is for users to be oblivious to the management of separate jams. When a user visits the app, the server should instruct the user's client which jam to join, and create new jams as each one fills up with users. The experience for the user will be near-instantaneous entry into a jam session without the need to manually join or switch channels on their own.

Additionally, as existing users leave the app and new ones visit, we should slot each new user into the most interesting jam at that time. This means telling their clients to join the jam with the most users currently jamming, so long as adding one more user wouldn't overflow the jam.

## Holding State

What we need is something to represent the state of all of our jams at any given time. For this we'll use an Elixir [Agent]. The agent will hold our state for us, and also provide a thin interface into the management and querying of that state. Let's put it in a module called `JamBalancer`.

The "thin interface" of the balancer is an important idiom. To keep our modules from taking on too many responsibilities and growing overwhelmingly large, we want to identify the responsibilities we need and then separate them out into different modules. The management of the state of our jams is a responsibility sufficient enough to stand on its own, so we limit the `JamBalancer` to this role.

Given the state of our jams at any time, provided by the jam balancer, we should be able to determine what to do with new users arriving at the app. This allows us to implement a new *stateless* module to do the hard work of providing us with the answers to our questions about that state. Let's call this new module `JamCollection`.

> Note that to make our discussion of the back end implementation as clear as possible, the listings in this post deviate a bit from those in the source links, by removing affordances made for testing. I'll follow up this post with another on how I've tested the back end.

With our design in hand, let's explore how these modules come together to provide our jam balancing functionality.

## Balancing Jams

To ensure that our jam balancer is available to our calling code, we'll need to start it up along with the application. Let's add it as a worker to our supervision tree [[source][Supervision tree]].

~~~ elixir
# lib/loops_with_friends.ex
defmodule LoopsWithFriends do
  use Application

  # ...

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # ...
      worker(LoopsWithFriends.JamBalancer, []),
    ]

    opts = [
      strategy: :one_for_one,
      name: LoopsWithFriends.Supervisor
    ]
    Supervisor.start_link(children, opts)
  end

  # ...
end
~~~

As the supervisor starts each of its children on application load, it will look for a `start_link` function in our balancer. Here we provide a wrapper around `Agent.start_link`, passing in a new `JamCollection` for the initial state.

~~~ elixir
# lib/loops_with_friends/jam_balancer.ex
defmodule LoopsWithFriends.JamBalancer do
  alias LoopsWithFriends.JamCollection

  @name __MODULE__

  def start_link(_opts) do
    Agent.start_link(fn -> JamCollection.new() end, name: @name)
  end
end
~~~

With our balancer started up, we can begin using it. When a user initially hits the app over HTTP, we need to let their client know which channel topic to join over the web socket. To provide this, we'll ask our jam balancer, "which jam is currently accepting users?"

~~~ html
<!-- web/templates/page/index.html.eex -->
<script>
  document.addEventListener("DOMContentLoaded", function (event) {
    var elmApp = Elm.App.fullscreen({
      host: document.location.host,
      topic: "jams:<%= JamBalancer.current_jam %>"
    });
  });
</script>
~~~

In the `current_jam` function, our `JamBalancer` module [[source][JamBalancer source] \| [test][JamBalancer test]] pulls the jam collection out of its agent and passes it to the `JamCollection` module, invoking the function `most_populated_jam_with_capacity_or_new`. Note again that all the balancer is doing is holding the state, and passing it along to another module to determine characteristics about that state.

~~~ elixir
# lib/loops_with_friends/jam_balancer.ex
defmodule LoopsWithFriends.JamBalancer do
  # ...

  def current_jam do
    JamCollection.most_populated_jam_with_capacity_or_new(jams)
  end

  defp jams do
    Agent.get(@name, &(&1))
  end
end
~~~

The `JamCollection` module is where the real work goes on. It's also where we see that collections are represented internally as maps.

In the first clause of the `most_populated_jam_with_capacity_or_new` function, we check to see if we have an empty collection, and if so, return a fresh jam ID back to the balancer so that a new jam can be started.

In the second clause, we go looking for the jam that has the most users, where that jam is not full. If no such jam exists because all jams are full, `jam_with_most_users_under_max` returns `nil`. In that case, our calling function detects the falsy value and returns a new jam ID.

~~~ elixir
# lib/loops_with_friends/jam_collection.ex
defmodule LoopsWithFriends.JamCollection do
  @max_users 7

  def new, do: %{}

  def most_populated_jam_with_capacity_or_new(jams)
    when jams == %{}, do: uuid()

  def most_populated_jam_with_capacity_or_new(jams) do
    jam_with_most_users_under_max(jams) || uuid()
  end

  # ...
end
~~~

I'll omit the implementation of `jam_with_most_users_under_max` here for brevity, but check out the full `JamCollection` module [[source][JamCollection source] \| [test][JamCollection test]] if you'd like to see it.

## Populating the Collection

At this point we've got a clear API written for asking our balancer and collection what jam we should return to the user. What we're missing is the management of the contents of that collection as users join and leave.

In our channel, let's hook into our existing `join` callback, and add a `terminate` callback. Calls to new balancer functions `refresh` and `remove_user` will supply the functionality we need.

~~~ elixir
# web/channels/jam_channel.ex
defmodule LoopsWithFriends.JamChannel do
  # ...

  def join("jams:" <> jam_id, _params, socket) do
    Presence.track # ...

    JamBalancer.refresh(jam_id, Presence.list(socket))

    # ...
  end

  def terminate(msg, socket) do
    JamBalancer.remove_user(
      socket.assigns.jam_id,
      socket.assigns.user_id
    )

    msg
  end

  # ...
end
~~~

Similarly to `current_jam`, our balancer will retrieve our jam collection state and forward the arguments for each of these functions to the collection module. The return values are new collections that get stored as the balancer's state.

~~~ elixir
# lib/loops_with_friends/jam_balancer.ex
defmodule LoopsWithFriends.JamBalancer do
  # ...

  def refresh(jam_id, presence_map) do
    Agent.update @name, fn jams ->
      JamCollection.refresh(jams, jam_id, Map.keys(presence_map))
    end
  end

  def remove_user(jam_id, user_id) do
    Agent.update @name, fn jams ->
      JamCollection.remove_user(jams, jam_id, user_id)
    end
  end

  # ...
end
~~~

See the full `JamCollection` module [[source][JamCollection source] \| [test][JamCollection test]] for the implementations of these functions.

In the [next post], we'll see that we need to consider timing issues with channel joining in order to ensure the best experience for our users.


[Loops With Friends]: http://loops-with-friends.herokuapp.com/
[first post]: ./2016-10-05-collaborative-music-loops-in-elixir-and-elm.html
[previous post]: ./2016-10-06-jamming-with-phoenix-presence.html
[Agent]: http://elixir-lang.org/getting-started/mix-otp/agent.html
[Supervision tree]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends.ex#L21
[JamBalancer source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_balancer/server.ex
[JamBalancer test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/lib/loops_with_friends/jam_balancer/server_test.exs
[JamCollection  source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection/collection.ex
[JamCollection test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/lib/loops_with_friends/jam_collection/collection_test.exs
[next post]: ./2016-10-08-phoenix-channel-race-conditions.html
