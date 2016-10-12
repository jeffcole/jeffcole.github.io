---
title: "Collaborative Music Loops in Elixir and Elm: Healthy Elixir Tests"
date: 2016-10-12 15:38 UTC
---

In the [first post] of this series we introduced the [Loops With Friends] app, and implemented channel joining, presence tracking, loop cycling, and event broadcasting with Elixir and Phoenix. In the [second post], we added jam balancing by leveraging an Elixir agent. Please see those posts to learn more about those topics.

This post will look at how the functional nature of Elixir makes applications written in it a joy to test. Elixir ships with the unit testing framework [ExUnit], which provides great testing support out of the box. We'll start with a brief look at testing Phoenix's abstractions around sockets and channels, and then move on to some techniques for building and maintaining a healthy test suite in Elixir.

## Testing Phoenix Sockets and Channels

Along with the code to support channel implementation, Phoenix also ships with code to make testing sockets and channels straightforward. This code lives in the `Phoenix.ChannelTest` module. The way that we take advantage of it is to `use` it in a module of our own, and then use *that* module in our actual test module. Note that this process is analogous to how we implemented presence in the [first post].

Specifically, we `use Phoenix.ChannelTest` in our `LoopsWithFriends` submodule `ChannelCase`, and then `use LoopsWithFriends.ChannelCase` in both of our `UserSocketTest` and `JamChannelTest` modules. Once we've done so, we have access to all of the functions and macros that [`Phoenix.ChannelTest`] provides. For instance, in [`UserSocketTest`], we use the `connect` macro to initialize a socket that we can then assert against.

~~~ elixir
# test/channels/user_socket_test.exs
defmodule LoopsWithFriends.UserSocketTest do
  use LoopsWithFriends.ChannelCase, async: true

  alias LoopsWithFriends.UserSocket

  test "`connect` assigns a UUID" do
    assert {:ok, socket} = connect(UserSocket, %{})

    # Ensure a valid UUID
    assert UUID.info!(socket.assigns.user_id)
  end
end
~~~

> The `async: true` on the `use` line lets ExUnit know that the tests in this module are safe to run asynchronously, which is a huge workflow boon for anyone familiar with slow test suites.

The tests in [`JamChannelTest`] similarly take advantage of Phoenix test functions and macros such as `subscribe_and_join`, `push`, `assert_push`, `refute_push`, and `assert_broadcast`.

## Injecting Agent Names

Let's move on to testing the components of our application that make it unique. As seen in the [previous post][second post], we leverage the `JamBalancer` module as a stateful representation of our collection of jams at any given time. One gotcha that I ran into as I was testing the balancer was that its tests would fail when I ran the full test suite, but not when I ran only the tests for the balancer module. After digging up [this thread post][Agent naming] by José Valim, I realized that the issue was due to both the unit and integration-level tests using the same balancer process. I was able to fix it by injecting an agent name into the `start_link` function of the [`JamBalancer`].

~~~ elixir
# lib/loops_with_friends/jam_balancer.ex
defmodule LoopsWithFriends.JamBalancer do
  # ...

  @name __MODULE__

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, @name)

    Agent.start_link(fn -> JamCollection.new(opts) end, opts)
  end

  # ...
end
~~~

This allows us to pass in the name of our balancer's test module as an option in its [unit test][JamBalancer.ServerTest].

~~~ elixir
# test/lib/loops_with_friends/jam_balancer_test.exs
defmodule LoopsWithFriends.JamBalancerTest do
  # ...

  @name __MODULE__

  describe "`start_link`" do
    test "starts a new jam collection" do
      result = JamBalancer.start_link(name: @name)

      assert {:ok, _pid} = result

  # ...
end
~~~

Outside of this unit test, when a balancer worker is started by our supervision tree in any environment, the agent is passed the name of the `JamBalancer` module as defaulted above. This technique allows us to keep different tests from using the same stateful process, and thus keep them from interfering with each other.

This use of [dependency injection] also embodies the good testing practice of treating our tests as first-class clients of our production code. In this case, if our code needs some context from the client, we shouldn't be afraid to inject that context, whether the client is either more production code, or a test. However, since everything is a trade-off, this is only a good practice so long as passing context doesn't lead us to overly couple our code with tight dependencies.

## Using Stubs to Isolate Tests

You may have noticed in the previous posts, and in the earlier sections of this post, that the module names in the source links sometimes differ from those shown in the posts' code listings. It's time to address why that is, via a discussion of isolated testing.

If you come from an object-oriented programming background, you may have had difficult experiences related to testing objects alongside their dependencies. When objects are tightly coupled, changes to one object can cause the tests for other objects to fail. This can result in a painful cycle of needing to change many different tests whenever a change to a single object is required.

The same scenario is possible in the functional world — the only difference is that we have modules and functions instead of objects and methods. The solution is to test and develop our application components in isolation as much as possible, while being sure to test the integration of these components separately. The [test pyramid] guides us in the direction of writing more focused, isolated, and fast unit tests, than interdependent and slower integration tests.

José Valim wrote an excellent post called [Mocks and Explicit Contracts] on how we can introduce new modules into our applications for the purposes of clarifying our code's responsibilities and isolating our tests.

> José's use of the term "mock" deviates a bit from Martin Fowler's [delineation][Mocks Aren't Stubs] of the differences between "mocks" and "stubs," in that to me, his usage appears closer to what Martin refers to a "stub." I find Martin's breakdown helpful, so although José calls them "mocks," I'll refer to these entities as "stubs."

In our application, we can use José's technique to isolate the `JamChannelTest` from the implementation of the `JamBalancer`, a module upon which the channel depends. First, we'll place our balancer implementation in a submodule called [`JamBalancer.Server`] (so named as an allusion to the fact that our balancer's `Agent` is a `GenServer` under the covers). Then we'll create another module, [`JamBalancer.Stub`], where we'll put the code that we want our [`JamChannelTest`] to run whenever it needs balancer functionality.

For example, here's the stub code for the `jam_capacity?` function. We're pattern matching on particular argument values for the `jam_id`, so that we can test what happens in the channel when the balancer indicates that a jam is full.

~~~ elixir
# lib/loops_with_friends/jam_balancer/stub.ex
defmodule LoopsWithFriends.JamBalancer.Stub do
  # ...

  def jam_capacity?(_agent \\ @name, jam_id)
  def jam_capacity?(_agent, "jam-1"), do: true
  def jam_capacity?(_agent, "full-jam"), do: false

  # ...
end
~~~

The next thing we need to do is tell our application when to use our `Server` and when to use our `Stub`. We accomplish this by setting the `Server` as the default in [`config.exs`], so that it will be used in both the production and development environments.

~~~ elixir
# config/config.exs
# ...

config :loops_with_friends, :jam_balancer,
  LoopsWithFriends.JamBalancer.Server

# ...
~~~

Then, we tell the test environment to use the `Stub` in [`test.exs`].

~~~ elixir
# config/test.exs
# ...

config :loops_with_friends, :jam_balancer,
  LoopsWithFriends.JamBalancer.Stub

# ...
~~~

Finally, we instruct the [`JamChannel`] to load the proper balancer for the current environment into a module attribute, rather than reference a module name directly.

~~~ elixir
# web/channels/jam_channel.ex
defmodule LoopsWithFriends.JamChannel do
  # ...

  @jam_balancer Application.get_env(
    :loops_with_friends,
    :jam_balancer
  )

  def join("jams:" <> jam_id, _params, socket) do
    if @jam_balancer.jam_capacity?(jam_id) do

  # ...
~~~

Now the channel will use the `Server` in production and development, while it will use the `Stub` in the test environment.

When our channel tests don't run any of our actual balancer code, they are isolated from changes to the balancer. This makes our tests more resilient to change, and therefore less brittle. Testing in this style can also lead you to naturally design modules and functions that are less coupled, resulting in an application that is easier to understand in pieces, and more pleasant to work on.

This technique was also useful when testing the balancer in isolation from the jam collection. I created a [`JamCollection.Stub`] module for use in the test environment, and placed the collection implementation in the [`JamCollection.Collection`] module.

Additionally, I used José's technique of making the contracts for balancers and collections explicit by using [Elixir behaviours], as seen in the [`JamCollection`] module.

## Testing Function Delegation

With our tests isolated from the dependencies of the modules they test, we're ready for the final technique I have to share. Recall that our jam balancer is a wrapper around the state of a jam collection. Most of the balancer's API consists of delegating function calls to the collection, which then returns values according to its own behavior. This poses an interesting problem for our tests. We want to test the balancer to ensure that it is behaving as expected, but we don't want to couple our tests to the behavior of the collection.

If you are familiar with testing object-oriented applications, in this situation you might reach for mocks in the way that Martin Fowler describes them. You might want to use a library to metaprogram an expectation that a particular function is called with certain arguments. However as José notes in his post above, in Elixir that would be a heavy-handed approach that would would hide close coupling.

Brian Cardarella proposes a solution in [this post][Testing Function Delegation], where he notes that in Elixir, we can verify our function delegation easily by sending messages between processes.

> Although the title of Brian's post is "Testing function delegation in Elixir without stubbing," I would argue that here again there might be a confusion of terms. I believe that Brian is doing essentially the opposite of what José did above, by using the term "stubbing" where it might be better to use "mocking." I would indeed call the modules that he constructs in his tests "stubs."
>
> These are my interpretations of José's and Brian's usage as seen through the lens of Martin Fowler's [definitions][Mocks Aren't Stubs], which are the most clear that I have found. When José and Brian take issue with stubbing and mocking, I believe that they are taking issue with the practice of using a library to obfuscate what in Elixir are simple tasks: dependency injection and message passing, respectively.

In our case, this approach is facilitated by the fact that we've already created a `Stub` for our `JamCollection` in the previous section. In [our balancer's test][JamBalancer.ServerTest], we call a function on the balancer module, and then indicate our desire that it call through to the collection with the ExUnit macro `assert_receive`.

~~~ elixir
defmodule LoopsWithFriends.JamBalancer.ServerTest do
  # ...

  alias LoopsWithFriends.JamBalancer.Server

  @name __MODULE__

  # ...

  describe "`jam_capacity?`" do
    setup :start_server

    test "asks the collection" do
      Server.jam_capacity?(@name, "jam-1")

      assert_receive :called_jam_collection_jam_capacity?
    end
  end

  # ...
~~~

The [`JamCollection.Stub`] module, which is used by the [`JamBalancer.Server`] in the test environment, provides a handy place to send a message back to the test process.

~~~ elixir
defmodule LoopsWithFriends.JamCollection.Stub do
  # ...

  def jam_capacity?(jams, _jam_id) do
    send self(), :called_jam_collection_jam_capacity?
  end

  # ...
end
~~~

With that, we've succeeded in verifying that our balancer delegates functions to our collection, without duplicating the tests for the return values of those functions, and without using a mocking library to hide communication between modules.

You might notice in the [`ServerTest`][JamBalancer.ServerTest] that for some tests, I used Brian's tip of passing the caller of a function as an option to that function, in order to allow the agent's process to send a message back to the test process. Very useful!

## Back to Front

The techniques outlined here have made building and testing the back end for Loops With Friends in Elixir a fun and rewarding experience. We've learned how to keep our tests on equal footing with our production code, how to isolate our tests from the dependencies of the function under test, and how to test function delegation in a simple way without increasing coupling.

Our back end done for now, so coming up next, we'll look at the wonders that Elm brings to the front end.


[first post]: ./2016-10-05-collaborative-music-loops-in-elixir-and-elm-the-back-end-part-1.html
[Loops With Friends]: http://loopswithfriends.com/
[second post]: ./2016-10-06-collaborative-music-loops-in-elixir-and-elm-the-back-end-part-2.html
[ExUnit]: http://elixir-lang.org/docs/stable/ex_unit/ExUnit.html
[`Phoenix.ChannelTest`]: https://hexdocs.pm/phoenix/Phoenix.ChannelTest.html
[`UserSocketTest`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/user_socket_test.exs
[`JamChannelTest`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/jam_channel_test.exs
[Agent naming]: https://groups.google.com/d/msg/elixir-lang-talk/TYBK6C7xHdg/Fv5o_CKvlSgJ
[`JamBalancer`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_balancer/server.ex
[JamBalancer.ServerTest]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/lib/loops_with_friends/jam_balancer/server_test.exs
[dependency injection]: https://en.wikipedia.org/wiki/Dependency_injection
[test pyramid]: http://martinfowler.com/bliki/TestPyramid.html
[Mocks and Explicit Contracts]: http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/
[Mocks Aren't Stubs]: http://martinfowler.com/articles/mocksArentStubs.html
[`JamBalancer.Server`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_balancer/server.ex
[`JamBalancer.Stub`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_balancer/stub.ex
[`config.exs`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/config/config.exs#L29
[`test.exs`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/config/test.exs#L19
[`JamChannel`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/web/channels/jam_channel.ex
[`JamCollection.Stub`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection/stub.ex
[`JamCollection.Collection`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection/collection.ex
[Elixir behaviours]: http://elixir-lang.org/getting-started/typespecs-and-behaviours.html#behaviours
[`JamCollection`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection.ex
[Testing Function Delegation]: https://dockyard.com/blog/2016/03/24/testing-function-delegation-in-elixir-without-stubbing
